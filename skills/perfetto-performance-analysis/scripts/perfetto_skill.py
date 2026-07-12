#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Mapping

from _common import (
    DEFAULT_MAX_OUTPUT_BYTES,
    parse_csv_output,
    render_sql_template,
    run_query,
    sha256_file,
    sql_literal,
    write_text_atomic,
)
from perfetto_query import (
    load_query_entry,
    parse_parameters,
    prepare_manifest_query,
    verify_manifest_schema,
)
from perfetto_doctor import resolve_verified_processor
from perfetto_probe import probe_trace
from runtime.executor import SkillRunner
from runtime.report import validate_report_payload
from runtime.validation import validate_query_execution


SKILL_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = SKILL_ROOT / "references" / "generated" / "runtime"


class ManifestCatalog:
    def __init__(self, runtime_root: Path = RUNTIME_ROOT):
        self.runtime_root = runtime_root
        self.index = json.loads((runtime_root / "skill-index.json").read_text(encoding="utf-8"))
        self._cache: dict[str, dict[str, Any]] = {}

    def load(self, skill_id: str) -> dict[str, Any]:
        if skill_id not in self.index["skills"]:
            raise KeyError(f"unknown Skill: {skill_id}")
        if skill_id not in self._cache:
            self._cache[skill_id] = json.loads(
                (self.runtime_root / self.index["skills"][skill_id]).read_text(encoding="utf-8")
            )
        return self._cache[skill_id]

    def graph(self, root_skill: str) -> dict[str, dict[str, Any]]:
        pending = [root_skill]
        result: dict[str, dict[str, Any]] = {}
        while pending:
            skill_id = pending.pop()
            if skill_id in result:
                continue
            skill = self.load(skill_id)
            result[skill_id] = skill
            for step in skill.get("steps", []):
                child = step.get("skill") or step.get("item_skill")
                if isinstance(child, str):
                    pending.append(child)
        return result


def resolve_identity(
    skill: Mapping[str, Any],
    params: Mapping[str, Any],
    *,
    trace: Path,
    trace_processor: str | None,
    timeout: float,
    max_output_bytes: int,
) -> dict[str, Any]:
    config = skill.get("identity", {}) or {"policy": "none"}
    policy = str(config.get("policy", "none"))
    if policy in {"none", "exempt"}:
        return {"status": "exempt", "policy": policy}
    aliases = [str(value) for value in config.get("aliases", [])]
    target_name = next(
        (str(params[name]) for name in aliases if params.get(name) not in (None, "")),
        None,
    )
    if target_name is None:
        return {"status": "not_requested", "policy": policy, "aliases": aliases}
    query = f"""
SELECT upid, pid, name, start_ts, end_ts
FROM process
WHERE name = {sql_literal(target_name)} OR name GLOB {sql_literal(target_name + ':*')}
ORDER BY CASE WHEN name = {sql_literal(target_name)} THEN 0 ELSE 1 END, start_ts;
""".strip()
    rows = parse_csv_output(
        run_query(
            trace,
            sql=query,
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        ).stdout
    )
    exact = [row for row in rows if row.get("name") == target_name]
    candidates = exact or rows
    if len(candidates) == 1:
        candidate = candidates[0]
        return {
            "status": "resolved",
            "policy": policy,
            "target": target_name,
            "upid": candidate.get("upid"),
            "pid": candidate.get("pid"),
            "process_name": candidate.get("name"),
            "lifetime": {"start_ns": candidate.get("start_ts"), "end_ns": candidate.get("end_ts")},
        }
    return {
        "status": "not_found" if not candidates else "ambiguous",
        "policy": policy,
        "target": target_name,
        "candidates": candidates,
    }


def build_runtime_runner(
    trace: Path,
    graph: Mapping[str, Any],
    *,
    trace_processor: str | None,
    timeout: float,
    max_output_bytes: int,
    allow_unverified: bool,
    probe: Mapping[str, Any],
    trace_side: str,
) -> SkillRunner:
    prerequisite_cache: dict[tuple[tuple[str, ...], tuple[str, ...]], dict[str, Any]] = {}
    resolved_trace = trace.expanduser().resolve()
    trace_sha256 = sha256_file(resolved_trace)

    def prerequisite_checker(skill: Mapping[str, Any]) -> Mapping[str, Any]:
        prerequisite = skill.get("prerequisites", {}) or {}
        modules = tuple(str(value) for value in prerequisite.get("modules", []))
        tables = tuple(str(value) for value in prerequisite.get("required_tables", []))
        cache_key = (modules, tables)
        if cache_key in prerequisite_cache:
            return prerequisite_cache[cache_key]
        includes = "\n".join(f"INCLUDE PERFETTO MODULE {module};" for module in modules)
        missing: list[str] = []
        for table in tables:
            try:
                run_query(
                    trace,
                    sql=f'{includes}\nSELECT * FROM "{table}" LIMIT 0;',
                    trace_processor=trace_processor,
                    timeout=timeout,
                    max_output_bytes=max_output_bytes,
                )
            except RuntimeError:
                missing.append(table)
        result = {
            "status": "satisfied" if not missing else "missing_evidence",
            "modules": list(modules),
            "missing": missing,
        }
        prerequisite_cache[cache_key] = result
        return result

    def identity_resolver(skill: Mapping[str, Any], params: Mapping[str, Any]) -> Mapping[str, Any]:
        return resolve_identity(
            skill,
            params,
            trace=trace,
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        )

    def query_executor(
        query_id: str,
        *,
        params: Mapping[str, Any],
        results: Mapping[str, Any],
        prelude: list[str],
    ) -> Mapping[str, Any]:
        del prelude
        entry = load_query_entry(query_id, SKILL_ROOT)
        gate = validate_query_execution(
            entry,
            probe,
            trace_sha256=trace_sha256,
            allow_unverified=allow_unverified,
            schema_tables=verify_manifest_schema(
                entry,
                trace,
                trace_processor=trace_processor,
                timeout=timeout,
                max_output_bytes=max_output_bytes,
            ),
        )
        template = prepare_manifest_query(entry, SKILL_ROOT)
        normalized_results = {
            name: value.get("data", value) if isinstance(value, Mapping) else value
            for name, value in results.items()
        }
        sql = render_sql_template(template, params, normalized_results)
        output = run_query(
            trace,
            sql=sql,
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        )
        rows = parse_csv_output(output.stdout)
        return {
            "rows": rows,
            "metadata": {
                "trace": {"path": str(resolved_trace), "sha256": trace_sha256, "side": trace_side},
                "query_source_sha256": entry["sha256"],
                "rendered_sql_sha256": hashlib.sha256(sql.encode("utf-8")).hexdigest(),
                "validation": entry["validation"],
                "compatibility": entry["compatibility"],
                "capability_gate": gate,
            },
        }

    return SkillRunner(
        {"skills": graph},
        query_executor,
        identity_resolver=identity_resolver,
        prerequisite_checker=prerequisite_checker,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run exported SmartPerfetto Skill graphs.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    list_parser = subparsers.add_parser("list", help="List portable Skill contracts.")
    list_parser.add_argument("--format", choices=("json", "text"), default="text")

    run_parser = subparsers.add_parser("run", help="Run one deterministic Skill graph.")
    run_parser.add_argument("trace", type=Path)
    run_parser.add_argument("--skill", required=True)
    run_parser.add_argument("--param", action="append", default=[], metavar="NAME=JSON")
    run_parser.add_argument("--trace-processor")
    run_parser.add_argument("--timeout", type=float, default=120.0)
    run_parser.add_argument("--max-output-bytes", type=int, default=DEFAULT_MAX_OUTPUT_BYTES)
    run_parser.add_argument("--allow-unverified", action="store_true")
    run_parser.add_argument("--trace-side", default="trace_a")
    run_parser.add_argument(
        "--allow-unsupported-processor",
        action="store_true",
        help="Explicitly bypass the pinned Perfetto release identity check.",
    )
    run_parser.add_argument("--output-dir", required=True, type=Path)

    verify_parser = subparsers.add_parser("verify-report", help="Validate a report v2 JSON file.")
    verify_parser.add_argument("report", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        catalog = ManifestCatalog()
        if args.command == "list":
            payload = {
                "schema_version": catalog.index["schema_version"],
                "summary": catalog.index["summary"],
                "skills": sorted(catalog.index["skills"]),
            }
            if args.format == "json":
                print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
            else:
                for skill_id in payload["skills"]:
                    print(skill_id)
            return 0
        if args.command == "verify-report":
            report = json.loads(args.report.read_text(encoding="utf-8"))
            issues = validate_report_payload(report)
            print(json.dumps({"status": "valid" if not issues else "invalid", "issues": issues}, ensure_ascii=False, indent=2))
            return 0 if not issues else 2
        processor, processor_identity = resolve_verified_processor(
            args.trace_processor,
            skill_root=SKILL_ROOT,
            allow_unsupported=args.allow_unsupported_processor,
        )
        graph = catalog.graph(args.skill)
        probe = probe_trace(
            args.trace,
            trace_processor=str(processor),
            timeout=args.timeout,
            max_output_bytes=args.max_output_bytes,
        )
        runner = build_runtime_runner(
            args.trace,
            graph,
            trace_processor=str(processor),
            timeout=args.timeout,
            max_output_bytes=args.max_output_bytes,
            allow_unverified=args.allow_unverified,
            probe=probe,
            trace_side=args.trace_side,
        )
        result = runner.run(args.skill, parse_parameters(args.param))
        result["processor"] = processor_identity
        for item in result.get("evidence", []):
            item["processor"] = processor_identity
            provenance = {key: value for key, value in item.items() if key != "evidence_id"}
            item["evidence_id"] = "ev_" + hashlib.sha256(
                json.dumps(
                    provenance,
                    ensure_ascii=False,
                    sort_keys=True,
                    separators=(",", ":"),
                    default=str,
                ).encode("utf-8")
            ).hexdigest()[:24]
        output_dir = args.output_dir.expanduser().resolve()
        output_dir.mkdir(parents=True, exist_ok=True)
        write_text_atomic(
            output_dir / "result.json",
            json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        )
        write_text_atomic(
            output_dir / "evidence.json",
            json.dumps(result.get("evidence", []), ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        )
        print(json.dumps({"status": result["status"], "result": str(output_dir / 'result.json')}, ensure_ascii=False))
        return 0 if result["success"] else 2
    except (KeyError, OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

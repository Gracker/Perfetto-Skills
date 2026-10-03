#!/usr/bin/env python3
from __future__ import annotations

import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Mapping

from _common import (
    DEFAULT_MAX_OUTPUT_BYTES,
    missing_tables,
    query_rows,
    render_sql_template,
    run_query,
    sha256_file,
    trace_processor_session,
    write_text_atomic,
)
from perfetto_query import (
    bind_manifest_process_scope,
    exact_variant,
    load_query_entry,
    manifest_process_scope_receipt,
    parse_parameters,
    prepare_manifest_query,
    raise_if_exact_unavailable,
    scope_evidence,
    verify_manifest_schema,
)
from perfetto_doctor import resolve_verified_processor
from perfetto_probe import probe_trace
from process_identity import RESOLVER_SKILL, IdentityGate, exact_scope_admission_error
from runtime.executor import SkillRunner, precheck_inputs
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
        missing = missing_tables(
            trace,
            tables,
            modules=modules,
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        )
        result = {
            "status": "satisfied" if not missing else "missing_evidence",
            "modules": list(modules),
            "missing": missing,
        }
        prerequisite_cache[cache_key] = result
        return result

    def query_executor(
        query_id: str,
        *,
        params: Mapping[str, Any],
        results: Mapping[str, Any],
        prelude: list[str],
        identity_result: Mapping[str, Any] | None = None,
        supplied_parameters: Mapping[str, Any] | None = None,
        identity_scope: Any = None,
    ) -> Mapping[str, Any]:
        del prelude
        exact = getattr(identity_scope, "mode", None) == "exact_upid"
        base_entry = load_query_entry(query_id, SKILL_ROOT)
        # Under an exact UPID scope the step's exact_sql variant is the query:
        # its own capability gate, schema, setups and template apply.
        entry = exact_variant(base_entry, SKILL_ROOT) if exact else base_entry
        binding_entries: list[tuple[dict[str, Any], str]] = []
        template = prepare_manifest_query(entry, SKILL_ROOT, binding_entries=binding_entries, exact=exact)
        if exact:
            # Declared unavailability is decided before any schema or capability work.
            raise_if_exact_unavailable(
                binding_entries, identity_scope, trace_sha256=trace_sha256, trace_side=trace_side,
            )
        declaration = binding_entries[-1][0].get("process_scope") if binding_entries else None

        def keep_scope_evidence(exc: BaseException) -> None:
            # A step whose query cannot run (schema, capability or SQL failure)
            # keeps its scope evidence, unavailable with the error; an optional
            # step reports it (SmartPerfetto's optional_query_error).
            if isinstance(declaration, Mapping):
                exc.scope_metadata = scope_evidence(  # type: ignore[attr-defined]
                    {**declaration, "exact_unavailable": str(exc)}, identity_scope, str(base_entry.get("step_id")),
                    None, trace_sha256=trace_sha256, trace_side=trace_side, unavailable=True,
                )

        try:
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
        except Exception as exc:
            keep_scope_evidence(exc)
            raise
        normalized_results = {
            name: value.get("data", value) if isinstance(value, Mapping) else value
            for name, value in results.items()
        }
        scope, _identity = bind_manifest_process_scope(
            binding_entries, params, supplied_parameters if supplied_parameters is not None else params,
            identity_result=identity_result, trace=resolved_trace,
            trace_sha256=trace_sha256, trace_side=trace_side,
            trace_processor=trace_processor, timeout=timeout, max_output_bytes=max_output_bytes,
            identity_scope=identity_scope, identity_owner=runner.identity_gate,
        )
        sql = render_sql_template(
            template, params, normalized_results,
            process_scope=scope, trace_sha256=trace_sha256, trace_side=trace_side,
        )
        try:
            output = run_query(
                trace,
                sql=sql,
                trace_processor=trace_processor,
                timeout=timeout,
                max_output_bytes=max_output_bytes,
            )
        except Exception as exc:
            keep_scope_evidence(exc)
            raise
        rows = query_rows(output)
        return {
            "rows": rows,
            "metadata": {
                "trace": {"path": str(resolved_trace), "sha256": trace_sha256, "side": trace_side},
                "query_source_sha256": entry["sha256"],
                "rendered_sql_sha256": hashlib.sha256(sql.encode("utf-8")).hexdigest(),
                "validation": entry["validation"],
                "compatibility": entry["compatibility"],
                "capability_gate": gate,
                **manifest_process_scope_receipt(binding_entries),
                **scope_evidence(
                    declaration, identity_scope, str(base_entry.get("step_id")), rows,
                    trace_sha256=trace_sha256, trace_side=trace_side,
                ),
            },
        }

    runner = SkillRunner(
        {"skills": graph},
        query_executor,
        prerequisite_checker=prerequisite_checker,
        process_scope_enabled=True,
    )

    def run_resolver(params: Mapping[str, Any]) -> tuple[bool, list[Mapping[str, Any]], str | None]:
        # SmartPerfetto resolves identity with its process_identity_resolver Skill.
        if RESOLVER_SKILL not in runner.skills:
            runner.skills.update(ManifestCatalog().graph(RESOLVER_SKILL))
        result = runner.run(RESOLVER_SKILL, dict(params))
        steps = result.get("steps") or []
        rows = next((step.get("rows") or [] for step in steps if step.get("step_id") == "root"), [])
        error = result.get("error") or next((step.get("error") for step in steps if step.get("error")), None)
        if not result.get("success") and error is None:
            error = str(result.get("status") or "resolver failed")
        return bool(result.get("success")), list(rows), error

    def count_pid(pid: int) -> tuple[Any, Any]:
        rows = query_rows(run_query(
            trace,
            sql=f"SELECT COUNT(DISTINCT upid) AS process_count, MIN(upid) AS unique_upid FROM process WHERE pid = {int(pid)}",
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        ))
        if len(rows) != 1:
            raise ValueError("PID uniqueness query returned incomplete facts")
        return rows[0].get("process_count"), rows[0].get("unique_upid")

    runner.identity_gate = IdentityGate(run_resolver, count_pid)
    catalog = ManifestCatalog()

    def load_skill(skill_id: str) -> Mapping[str, Any] | None:
        try:
            return runner.skills.get(skill_id) or catalog.load(skill_id)
        except (KeyError, OSError, ValueError):
            return None

    runner.exact_admission = lambda skill_id: exact_scope_admission_error(
        skill_id, load_skill, lambda query_id: load_query_entry(query_id, SKILL_ROOT),
        lambda: sorted(catalog.index["skills"]),
    )
    return runner



def build_identity_gate(
    trace: Path, *, trace_processor: str | None, timeout: float, max_output_bytes: int,
    allow_unverified: bool, probe: Mapping[str, Any], trace_side: str,
) -> IdentityGate:
    """The identity gate a Skill run on `trace` applies, for a single manifest query."""
    return build_runtime_runner(
        trace, {}, trace_processor=trace_processor, timeout=timeout, max_output_bytes=max_output_bytes,
        allow_unverified=allow_unverified, probe=probe, trace_side=trace_side,
    ).identity_gate


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
    sessions = ExitStack()
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
        params = parse_parameters(args.param)
        graph = catalog.graph(args.skill)
        # Refuse names the Skill cannot take before any trace work; the identity
        # gate may consume selectors and fill declared inputs, so the full
        # input contract applies to the parameters it returns.
        precheck_inputs(args.skill, graph[args.skill], params)
        processor, processor_identity = resolve_verified_processor(
            args.trace_processor,
            skill_root=SKILL_ROOT,
            allow_unsupported=args.allow_unsupported_processor,
        )
        # The probe and every step query share one trace load.
        sessions.enter_context(trace_processor_session(args.trace, trace_processor=str(processor)))
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
        result = runner.run(args.skill, params)
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
    finally:
        sessions.close()


if __name__ == "__main__":
    raise SystemExit(main())

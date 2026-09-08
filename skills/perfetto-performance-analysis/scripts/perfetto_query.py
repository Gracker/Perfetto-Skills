#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
import hashlib
import copy
from collections.abc import Mapping

from _common import (
    DEFAULT_MAX_OUTPUT_BYTES,
    RuntimeProcessScope,
    bind_runtime_process_scope,
    parse_csv_output,
    render_sql_template,
    reject_process_scope_names,
    resolve_identity,
    runtime_sql_bindings,
    run_query,
    sha256_file,
    sql_template_names,
    validate_process_scope_declaration,
    write_text_atomic,
)
from perfetto_doctor import resolve_verified_processor
from perfetto_probe import probe_trace
from runtime.validation import validate_query_execution


MODULE_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_.]*$")


def split_assignment(value: str, label: str) -> tuple[str, str]:
    name, separator, raw = value.partition("=")
    if not separator or not name:
        raise ValueError(f"{label} must use NAME=VALUE")
    return name, raw


def parse_parameters(values: list[str]) -> dict[str, object]:
    parameters: dict[str, object] = {}
    for item in values:
        name, raw = split_assignment(item, "--param")
        if name in parameters:
            raise ValueError(f"duplicate --param: {name}")
        try:
            parameters[name] = json.loads(raw)
        except json.JSONDecodeError:
            parameters[name] = raw
    return parameters


def load_results(values: list[str]) -> dict[str, object]:
    results: dict[str, object] = {}
    for item in values:
        name, raw_path = split_assignment(item, "--result")
        if name in results:
            raise ValueError(f"duplicate --result: {name}")
        path = Path(raw_path).expanduser().resolve()
        results[name] = json.loads(path.read_text(encoding="utf-8"))
    return results


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run one Perfetto SQL result set with trace_processor_shell."
    )
    parser.add_argument("trace", type=Path)
    query = parser.add_mutually_exclusive_group(required=True)
    query.add_argument("--sql", help="Inline Perfetto SQL.")
    query.add_argument("--sql-file", type=Path, help="UTF-8 SQL file.")
    query.add_argument("--query-id", help="Manifest query ID (skill/step).")
    parser.add_argument("--trace-processor")
    parser.add_argument("--trace-side", default="trace_a")
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument(
        "--max-output-bytes",
        type=int,
        default=DEFAULT_MAX_OUTPUT_BYTES,
        help="Maximum stdout and stderr bytes accepted from trace_processor_shell.",
    )
    parser.add_argument(
        "--param",
        action="append",
        default=[],
        metavar="NAME=JSON",
        help=(
            "Bind ${NAME} using a JSON scalar, a JSON array for an SQL literal "
            "list, or a raw string."
        ),
    )
    parser.add_argument(
        "--result",
        action="append",
        default=[],
        metavar="NAME=PATH",
        help=(
            "Bind ${NAME} to a non-empty JSON row array; dotted fields and "
            "numeric indexes select scalar values."
        ),
    )
    parser.add_argument(
        "--module",
        action="append",
        default=[],
        help="Prepend a validated INCLUDE PERFETTO MODULE statement.",
    )
    parser.add_argument("--format", choices=("json", "csv", "raw"), default="json")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--evidence-output", type=Path)
    parser.add_argument(
        "--allow-unverified",
        action="store_true",
        help="Explicitly run a manifest query whose validation policy is unverified.",
    )
    parser.add_argument(
        "--allow-unsupported-processor",
        action="store_true",
        help="Explicitly bypass the pinned Perfetto release identity check for a manifest query.",
    )
    return parser


def _safe_component(value: str) -> str:
    normalized = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-.")
    if not normalized:
        raise ValueError(f"invalid manifest component: {value!r}")
    return normalized


def load_query_entry(query_id: str, skill_root: Path) -> dict[str, object]:
    skill_id, separator, _step_id = query_id.partition("/")
    if not separator:
        raise ValueError("--query-id must use SKILL/STEP")
    runtime = skill_root / "references" / "generated" / "runtime"
    index = json.loads((runtime / "sql-index.json").read_text(encoding="utf-8"))
    relative = f"queries/{_safe_component(skill_id)}.json"
    if relative not in index["shards"]:
        raise ValueError(f"unknown manifest Skill: {skill_id}")
    shard = json.loads((runtime / relative).read_text(encoding="utf-8"))
    for entry in shard["queries"]:
        if entry["id"] == query_id:
            return entry
    raise ValueError(f"unknown manifest query: {query_id}")


def prepare_manifest_query(
    entry: dict[str, object], skill_root: Path,
    *, binding_entries: list[tuple[dict[str, object], str]] | None = None,
) -> str:
    """Assemble SQL and optionally collect the exact descriptors in its closure."""
    generated = skill_root / "references" / "generated"
    setup_sql: list[str] = []
    visited: set[str] = set()

    def append_setup(query_id: str) -> None:
        if query_id in visited or query_id == entry["id"]:
            return
        visited.add(query_id)
        setup = load_query_entry(query_id, skill_root)
        for dependency in setup["sql_dependencies"].get("setup_queries", []):
            append_setup(str(dependency))
        text = (generated / str(setup["path"])).read_text(encoding="utf-8").rstrip()
        if binding_entries is not None:
            binding_entries.append((setup, text))
        setup_sql.append(text if text.endswith(";") else text + ";")

    for query_id in entry["sql_dependencies"].get("setup_queries", []):
        append_setup(str(query_id))
    sql = (generated / str(entry["path"])).read_text(encoding="utf-8")
    if binding_entries is not None:
        binding_entries.append((entry, sql))
    modules = entry["sql_dependencies"].get("declared_modules", [])
    includes = "\n".join(
        f"INCLUDE PERFETTO MODULE {module};" for module in modules
    )
    return "\n".join(value for value in (includes, *setup_sql, sql) if value)


def bind_manifest_process_scope(
    entries: list[tuple[dict[str, object], str]],
    parameters: Mapping[str, object],
    supplied_parameters: Mapping[str, object],
    *, identity_result: Mapping[str, object] | None,
    trace: Path, trace_sha256: str, trace_side: str,
    trace_processor: str | None, timeout: float, max_output_bytes: int,
) -> tuple[RuntimeProcessScope | None, Mapping[str, object] | None]:
    reject_process_scope_names(parameters)
    reject_process_scope_names(supplied_parameters)
    requirements: list[tuple[Mapping[str, object], list[str], str]] = []
    for entry, sql in entries:
        declaration = entry.get("process_scope")
        role = validate_process_scope_declaration(declaration) if "process_scope" in entry else None
        compatibility = entry.get("compatibility", {})
        exact = compatibility.get("exact_scope", {}) if isinstance(compatibility, Mapping) else {}
        if isinstance(exact, Mapping) and exact.get("status") == "unsupported" and any(
            selector in supplied_parameters for selector in ("upid", "pid")
        ):
            raise ValueError("exact process scope is unsupported for this query")
        template = entry.get("template", {})
        if not isinstance(template, Mapping):
            raise ValueError("invalid SQL template declaration")
        names = sql_template_names(sql)
        reserved = set(runtime_sql_bindings(sql))
        declared = template.get("runtime_bindings", [])
        if not isinstance(declared, list) or not all(isinstance(name, str) for name in declared):
            raise ValueError("invalid runtime binding declaration")
        if set(declared) != reserved:
            raise ValueError("runtime binding declaration does not match SQL")
        if not reserved:
            continue
        identity = entry.get("identity")
        if role is None:
            raise ValueError("process scope declaration is required")
        if not isinstance(identity, Mapping):
            raise ValueError("process scope identity policy is required")
        aliases = identity.get("aliases", [])
        if not isinstance(aliases, list) or not all(isinstance(name, str) for name in aliases):
            raise ValueError("invalid identity aliases")
        consumed_names = sorted(set(aliases) & names)
        if template.get("name_parameters") != consumed_names:
            raise ValueError("identity name parameters do not match SQL")
        requirements.append((identity, consumed_names, role))
    if not requirements:
        return None, identity_result
    identity = identity_result
    if identity is None:
        identity = resolve_identity(
            {"identity": requirements[0][0]}, parameters, trace=trace,
            trace_processor=trace_processor, timeout=timeout, max_output_bytes=max_output_bytes,
        )
    # Every target query must retain its own name predicate. A context query's
    # names cannot supply a missing target predicate elsewhere in the closure.
    all_names: set[str] = set()
    all_aliases: set[str] = set()
    all_roles: set[str] = set()
    for policy, names, role in requirements:
        bind_runtime_process_scope(
            identity, identity_policy=policy, parameters=parameters,
            supplied_parameters=supplied_parameters, name_parameters=names,
            trace_sha256=trace_sha256, trace_side=trace_side,
            scope_roles=(role,),
        )
        if role == "target":
            all_names.update(names)
        all_aliases.update(policy.get("aliases", []))
        all_roles.add(role)
    policy = {**requirements[0][0], "aliases": sorted(all_aliases)}
    scope = bind_runtime_process_scope(
        identity, identity_policy=policy, parameters=parameters,
        supplied_parameters=supplied_parameters, name_parameters=sorted(all_names),
        trace_sha256=trace_sha256, trace_side=trace_side,
        scope_roles=tuple(sorted(all_roles)),
    )
    return scope, identity


def manifest_process_scope_receipt(entries: list[tuple[dict[str, object], str]]) -> dict[str, object]:
    """Preserve authored roles; these declarations do not certify target rows."""
    receipt: dict[str, object] = {}
    if not entries:
        return receipt
    leaf = entries[-1][0]
    if "process_scope" in leaf:
        receipt["process_scope"] = copy.deepcopy(leaf["process_scope"])
    setups = [
        {"query_id": entry["id"], "process_scope": copy.deepcopy(entry["process_scope"])}
        for entry, _sql in entries[:-1] if "process_scope" in entry
    ]
    if setups:
        receipt["setup_process_scopes"] = setups
    return receipt


def verify_manifest_schema(
    entry: dict[str, object],
    trace: Path,
    *,
    trace_processor: str | None,
    timeout: float,
    max_output_bytes: int,
) -> set[str]:
    dependencies = entry["sql_dependencies"]
    modules = dependencies.get("declared_modules", [])
    includes = "\n".join(
        f"INCLUDE PERFETTO MODULE {module};" for module in modules
    )
    verified: set[str] = set()
    if modules:
        run_query(
            trace,
            sql=f"{includes}\nSELECT 1 AS module_schema_ready;",
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        )
    for table in dependencies.get("required_tables", []):
        run_query(
            trace,
            sql=f'{includes}\nSELECT * FROM "{table}" LIMIT 0;',
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        )
        verified.add(str(table))
    return verified


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if any(not MODULE_PATTERN.fullmatch(module) for module in args.module):
            raise ValueError("--module names may contain only letters, digits, dots, and underscores")
        skill_root = Path(__file__).resolve().parents[1]
        manifest_entry = None
        identity = None
        scope = None
        trace_sha256 = None
        params = parse_parameters(args.param)
        results = load_results(args.result)
        reject_process_scope_names(params)
        reject_process_scope_names(results)
        processor_identity = None
        trace_processor = args.trace_processor
        if args.query_id:
            processor, processor_identity = resolve_verified_processor(
                args.trace_processor,
                skill_root=skill_root,
                allow_unsupported=args.allow_unsupported_processor,
            )
            trace_processor = str(processor)
            manifest_entry = load_query_entry(args.query_id, skill_root)
            resolved_trace = args.trace.expanduser().resolve()
            trace_sha256 = sha256_file(resolved_trace)
            probe = probe_trace(
                args.trace,
                trace_processor=trace_processor,
                timeout=args.timeout,
                max_output_bytes=args.max_output_bytes,
            )
            capability_gate = validate_query_execution(
                manifest_entry,
                probe,
                trace_sha256=trace_sha256,
                allow_unverified=args.allow_unverified,
                schema_tables=verify_manifest_schema(
                    manifest_entry,
                    args.trace,
                    trace_processor=trace_processor,
                    timeout=args.timeout,
                    max_output_bytes=args.max_output_bytes,
                ),
            )
            binding_entries: list[tuple[dict[str, object], str]] = []
            template = prepare_manifest_query(manifest_entry, skill_root, binding_entries=binding_entries)
            scope, identity = bind_manifest_process_scope(
                binding_entries, params, params, identity_result=None,
                trace=resolved_trace, trace_sha256=trace_sha256, trace_side=args.trace_side,
                trace_processor=trace_processor, timeout=args.timeout, max_output_bytes=args.max_output_bytes,
            )
        else:
            template = (
                args.sql_file.read_text(encoding="utf-8")
                if args.sql_file is not None
                else args.sql
            )
        assert template is not None
        sql = render_sql_template(
            template,
            params,
            results,
            process_scope=scope, trace_sha256=trace_sha256, trace_side=args.trace_side,
        )
        if args.module:
            includes = "\n".join(
                f"INCLUDE PERFETTO MODULE {module};" for module in args.module
            )
            sql = includes + "\n" + sql
        result = run_query(
            args.trace,
            sql=sql,
            trace_processor=trace_processor,
            timeout=args.timeout,
            max_output_bytes=args.max_output_bytes,
        )
        rows = parse_csv_output(result.stdout)
        if args.format == "json":
            rendered = json.dumps(
                rows,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n"
        else:
            rendered = result.stdout
        if args.output:
            write_text_atomic(args.output, rendered)
        else:
            sys.stdout.write(rendered)
        if result.stderr:
            sys.stderr.write(result.stderr)
        if manifest_entry is not None:
            evidence_path = args.evidence_output
            if evidence_path is None and args.output is not None:
                evidence_path = args.output.with_suffix(args.output.suffix + ".evidence.json")
            if evidence_path is None:
                raise ValueError("--query-id requires --output or --evidence-output for its mandatory sidecar")
            resolved_trace = args.trace.expanduser().resolve()
            params = parse_parameters(args.param)
            evidence = {
                "schema_version": 1,
                "evidence_id": "ev_" + hashlib.sha256(
                    json.dumps(
                        {
                            "trace": sha256_file(resolved_trace),
                            "trace_side": args.trace_side,
                            "query": manifest_entry["id"],
                            "sql": hashlib.sha256(sql.encode("utf-8")).hexdigest(),
                            "params": params,
                            "processor": processor_identity["binary_sha256"],
                        },
                        sort_keys=True,
                    ).encode("utf-8")
                ).hexdigest()[:24],
                "trace": {"path": str(resolved_trace), "sha256": sha256_file(resolved_trace), "side": args.trace_side},
                "query": {
                    "id": manifest_entry["id"],
                    "source_sha256": manifest_entry["sha256"],
                    "rendered_sha256": hashlib.sha256(sql.encode("utf-8")).hexdigest(),
                    "params_sha256": hashlib.sha256(
                        json.dumps(params, sort_keys=True).encode("utf-8")
                    ).hexdigest(),
                },
                "validation": manifest_entry["validation"],
                "capability_gate": capability_gate,
                "processor": processor_identity,
                "identity": identity if identity is not None else {"status": "not_checked", "policy": "none"},
                **manifest_process_scope_receipt(binding_entries),
                "status": "observed" if rows else "empty",
                "row_count": len(rows),
                "rows": rows,
            }
            write_text_atomic(
                evidence_path,
                json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            )
        return 0
    except (OSError, json.JSONDecodeError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import argparse
from contextlib import ExitStack
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
    include_modules_sql,
    query_rows,
    render_sql_template,
    reject_process_scope_names,
    runtime_sql_bindings,
    run_query,
    sha256_file,
    sql_template_names,
    table_access_sql,
    trace_processor_session,
    validate_process_scope_declaration,
    write_text_atomic,
)
from perfetto_doctor import resolve_verified_processor
from perfetto_probe import probe_trace
from runtime.executor import precheck_inputs, without_consumed_selectors
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


class ExactScopeUnavailable(ValueError):
    """An exact UPID scope reached SQL whose author declared it cannot run exactly."""

    code = "exact_scope_unavailable"


def exact_variant(entry: dict[str, object], skill_root: Path) -> dict[str, object]:
    """The query an exact UPID scope runs: its exact_sql variant when it has one
    (SmartPerfetto's selectProcessScopeSql)."""
    exact = (entry.get("compatibility") or {}).get("exact_scope") or {}
    variant = exact.get("exact_query_id") if isinstance(exact, Mapping) else None
    return load_query_entry(str(variant), skill_root) if variant else entry


def prepare_manifest_query(
    entry: dict[str, object], skill_root: Path,
    *, binding_entries: list[tuple[dict[str, object], str]] | None = None,
    exact: bool = False,
) -> str:
    """Assemble SQL and optionally collect the exact descriptors in its closure.

    Under an exact UPID scope every query in the closure runs its exact variant.
    """
    generated = skill_root / "references" / "generated"
    setup_sql: list[str] = []
    visited: set[str] = set()
    if exact:
        entry = exact_variant(entry, skill_root)

    def append_setup(query_id: str) -> None:
        if query_id in visited or query_id == entry["id"]:
            return
        visited.add(query_id)
        setup = load_query_entry(query_id, skill_root)
        if exact:
            setup = exact_variant(setup, skill_root)
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
    includes = include_modules_sql(modules)
    return "\n".join(value for value in (includes, *setup_sql, sql) if value)


def bind_manifest_process_scope(
    entries: list[tuple[dict[str, object], str]],
    parameters: Mapping[str, object],
    supplied_parameters: Mapping[str, object],
    *, identity_result: Mapping[str, object] | None,
    trace: Path, trace_sha256: str, trace_side: str,
    trace_processor: str | None, timeout: float, max_output_bytes: int,
    identity_scope: object | None = None,
    identity_owner: object | None = None,
) -> tuple[RuntimeProcessScope | None, Mapping[str, object] | None]:
    reject_process_scope_names(parameters)
    reject_process_scope_names(supplied_parameters)
    exact_upid = verified_exact_upid(identity_scope, identity_owner)
    if exact_upid is not None:
        raise_if_exact_unavailable(entries, identity_scope, trace_sha256=trace_sha256, trace_side=trace_side)
    requirements: list[tuple[Mapping[str, object], list[str], str]] = []
    for entry, sql in entries:
        role = validate_process_scope_declaration(entry.get("process_scope")) if "process_scope" in entry else None
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
        raise ValueError("process scope binding requires the identity gate's result")
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
            scope_roles=(role,), exact_upid=exact_upid,
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
        scope_roles=tuple(sorted(all_roles)), exact_upid=exact_upid,
    )
    return scope, identity


def raise_if_exact_unavailable(
    entries: list[tuple[dict[str, object], str]], identity_scope: object | None,
    *, trace_sha256: str, trace_side: str,
) -> None:
    """Refuse, before any trace work, an exact closure that cannot run exactly.

    Every assembled query must be supported under an exact scope; a query whose
    author declared it unavailable raises ExactScopeUnavailable with its scope
    evidence (SmartPerfetto's exact_scope_unavailable step result).
    """
    for entry, _sql in entries:
        compatibility = entry.get("compatibility", {})
        exact = compatibility.get("exact_scope", {}) if isinstance(compatibility, Mapping) else {}
        if not isinstance(exact, Mapping) or exact.get("status") != "supported":
            reason = exact.get("reason") if isinstance(exact, Mapping) else None
            raise ValueError(f"Exact UPID scope is unsupported: {entry['id']}: {reason or 'SQL has no process_scope declaration'}")
        declaration = entry.get("process_scope")
        if isinstance(declaration, Mapping) and declaration.get("exact_unavailable"):
            unavailable = ExactScopeUnavailable(str(declaration["exact_unavailable"]))
            unavailable.metadata = scope_evidence(
                declaration, identity_scope, str(entry.get("step_id")), None,
                trace_sha256=trace_sha256, trace_side=trace_side, unavailable=True,
            )
            raise unavailable


def verified_exact_upid(identity_scope: object | None, owner: object | None) -> int | None:
    """The UPID of an exact identity scope issued by `owner`, the identity gate of
    the trace and side this SQL runs on; None for any other scope mode."""
    from process_identity import IdentityScope

    if not isinstance(identity_scope, IdentityScope) or identity_scope.mode != "exact_upid":
        return None
    if owner is None or not identity_scope.issued_by(owner) or not isinstance(identity_scope.upid, int):
        raise ValueError("Process scope is untrusted or belongs to a different trace/side")
    return identity_scope.upid


def _scope_record(identity_scope: object | None, trace_sha256: str, trace_side: str) -> dict[str, object]:
    record: dict[str, object] = {"mode": "unscoped", "trace_sha256": trace_sha256, "trace_side": trace_side}
    mode = getattr(identity_scope, "mode", None)
    if mode == "exact_upid":
        record.update(mode="exact_upid", upid=identity_scope.upid)  # type: ignore[union-attr]
    elif mode == "named":
        record.update(mode="named", requested_name=identity_scope.requested_name)  # type: ignore[union-attr]
    return record


def scope_evidence(
    declaration: Mapping[str, object] | None, identity_scope: object | None, step_id: str, rows: object,
    *, trace_sha256: str, trace_side: str, unavailable: bool = False,
) -> dict[str, object]:
    """Which process scope each part of a step's evidence was measured under
    (SmartPerfetto's sqlScopeEvidence and scopeMetadata, without its UI fields).

    Only a single available target entry carries `applied_process_scope`;
    context roles and unavailable evidence never claim the target's scope.
    """
    if not isinstance(declaration, Mapping):
        return {}
    target = _scope_record(identity_scope, trace_sha256, trace_side)
    global_scope = {"mode": "unscoped", "trace_sha256": trace_sha256, "trace_side": trace_side}
    contexts = list((declaration.get("context_fields") or {}).items())  # type: ignore[union-attr]
    context_fields = {field for _role, fields in contexts for field in fields}
    first = rows[0] if isinstance(rows, list) and rows else rows
    fields = list(first) if isinstance(first, Mapping) else []
    role = declaration.get("role")
    entry: dict[str, object] = {
        "role": role, "scope": target if role == "target" else global_scope, "source_step_id": step_id,
        "availability": "unavailable" if unavailable else "available",
    }
    if contexts:
        entry["fields"] = [field for field in fields if field not in context_fields]
    if unavailable:
        entry["reason"] = declaration.get("exact_unavailable")
    if role != "target":
        entry["relative_to"] = target
    entries = [entry] + [
        {"role": context_role, "scope": global_scope, "source_step_id": step_id, "fields": list(columns),
         "availability": "available", "relative_to": target}
        for context_role, columns in contexts
    ]
    roles = {str(item["role"]) for item in entries}
    only = entries[0] if len(entries) == 1 else None
    result: dict[str, object] = {
        "scope_provenance": {"version": "process_scope_evidence@1", "entries": entries},
        "evidence_role": next(iter(roles)) if len(roles) == 1 else "mixed",
    }
    if only and only["role"] == "target" and only["availability"] != "unavailable" and only.get("fields") != []:
        result["applied_process_scope"] = only["scope"]
    if declaration.get("limitations"):
        result["scope_limitations"] = list(declaration["limitations"])  # type: ignore[arg-type]
    return result


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
    includes = include_modules_sql(modules)
    tables = [str(table) for table in dependencies.get("required_tables", [])]
    if not modules and not tables:
        return set()
    # One invocation: trace_processor_shell stops at the first failing statement.
    ready = "SELECT 1 AS module_schema_ready;" if modules else ""
    run_query(
        trace,
        sql=f"{includes}\n{ready}\n{table_access_sql(tables)}",
        trace_processor=trace_processor,
        timeout=timeout,
        max_output_bytes=max_output_bytes,
    )
    return set(tables)


def write_query_evidence(
    args: argparse.Namespace, manifest_entry: Mapping[str, object], processor_identity: Mapping[str, object],
    *, executed_entry: Mapping[str, object], sql: str | None, rows: list[object],
    capability_gate: object, identity: object,
    receipt: Mapping[str, object], scope: Mapping[str, object], status: str,
    failure: Mapping[str, object] | None = None,
) -> None:
    """The mandatory --query-id evidence sidecar; `sql` is None when no SQL ran.

    `query.id` is the requested query; its source hash and validation are those
    of the SQL that ran, the exact_sql variant under an exact UPID scope.
    """
    evidence_path = args.evidence_output
    if evidence_path is None and args.output is not None:
        evidence_path = args.output.with_suffix(args.output.suffix + ".evidence.json")
    if evidence_path is None:
        raise ValueError("--query-id requires --output or --evidence-output for its mandatory sidecar")
    resolved_trace = args.trace.expanduser().resolve()
    trace_sha256 = sha256_file(resolved_trace)
    params = parse_parameters(args.param)
    rendered = hashlib.sha256(sql.encode("utf-8")).hexdigest() if sql is not None else None
    evidence = {
        "schema_version": 1,
        "evidence_id": "ev_" + hashlib.sha256(
            json.dumps(
                {
                    "trace": trace_sha256,
                    "trace_side": args.trace_side,
                    "query": manifest_entry["id"],
                    "sql": rendered,
                    "params": params,
                    "processor": processor_identity["binary_sha256"],
                },
                sort_keys=True,
            ).encode("utf-8")
        ).hexdigest()[:24],
        "trace": {"path": str(resolved_trace), "sha256": trace_sha256, "side": args.trace_side},
        "query": {
            "id": manifest_entry["id"],
            **({"executed_id": executed_entry["id"]} if executed_entry["id"] != manifest_entry["id"] else {}),
            "source_sha256": executed_entry["sha256"],
            "rendered_sha256": rendered,
            "params_sha256": hashlib.sha256(json.dumps(params, sort_keys=True).encode("utf-8")).hexdigest(),
        },
        "validation": executed_entry["validation"],
        "capability_gate": capability_gate,
        "processor": processor_identity,
        "identity": identity,
        **receipt,
        **scope,
        **(failure or {}),
        "status": status,
        "row_count": len(rows),
        "rows": rows,
    }
    write_text_atomic(evidence_path, json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    sessions = ExitStack()
    try:
        if any(not MODULE_PATTERN.fullmatch(module) for module in args.module):
            raise ValueError("--module names may contain only letters, digits, dots, and underscores")
        skill_root = Path(__file__).resolve().parents[1]
        manifest_entry = None
        identity = None
        gate_scope = None
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
            # The schema check, probe and query below share one trace load.
            sessions.enter_context(trace_processor_session(args.trace, trace_processor=trace_processor))
            manifest_entry = load_query_entry(args.query_id, skill_root)
            # The query's parameters are its declared inputs: refuse any other
            # name, except a selector the identity gate consumes, before trace work.
            query_skill = {
                "id": manifest_entry.get("skill_id"),
                "identity": manifest_entry.get("identity") or {"policy": "none"},
                "inputs": [{"name": name} for name in manifest_entry.get("template", {}).get("parameters", [])],
            }
            precheck_inputs(str(query_skill["id"]), query_skill, params)
            resolved_trace = args.trace.expanduser().resolve()
            trace_sha256 = sha256_file(resolved_trace)
            probe = probe_trace(
                args.trace,
                trace_processor=trace_processor,
                timeout=args.timeout,
                max_output_bytes=args.max_output_bytes,
            )
            # The same identity gate a Skill run applies, whether or not this
            # query's SQL carries a reserved process-scope binding.
            from perfetto_skill import build_identity_gate

            identity_gate = build_identity_gate(
                args.trace, trace_processor=trace_processor, timeout=args.timeout,
                max_output_bytes=args.max_output_bytes, allow_unverified=args.allow_unverified,
                probe=probe, trace_side=args.trace_side,
            )
            gate = identity_gate.apply(query_skill, params, {})
            if not gate.allowed:
                raise ValueError(gate.error)
            supplied = params
            params = without_consumed_selectors(str(query_skill["id"]), query_skill, gate.params)
            gate_scope = gate.scope
            exact = getattr(gate.scope, "mode", None) == "exact_upid"
            # Under an exact UPID scope the query's exact_sql variant runs; its own
            # capability gate and schema apply.
            executed_entry = exact_variant(manifest_entry, skill_root) if exact else manifest_entry
            if exact:
                from process_identity import query_exact_support

                reason = query_exact_support(
                    str(manifest_entry["id"]), lambda query_id: load_query_entry(query_id, skill_root),
                    str(manifest_entry["id"]),
                )
                if reason:
                    raise ValueError(f"Exact UPID scope is unsupported: {reason}.")
            binding_entries: list[tuple[dict[str, object], str]] = []
            template = prepare_manifest_query(
                manifest_entry, skill_root, binding_entries=binding_entries, exact=exact,
            )
            if exact:
                # Declared unavailability is decided before any schema or
                # capability work, and still leaves its evidence sidecar.
                try:
                    raise_if_exact_unavailable(
                        binding_entries, gate.scope, trace_sha256=trace_sha256, trace_side=args.trace_side,
                    )
                except ExactScopeUnavailable as unavailable:
                    write_query_evidence(
                        args, manifest_entry, processor_identity, executed_entry=executed_entry, sql=None, rows=[],
                        capability_gate=None, identity=gate.evidence(),
                        receipt=manifest_process_scope_receipt(binding_entries),
                        scope=dict(unavailable.metadata), status="unavailable",
                        failure={
                            "code": unavailable.code, "error": str(unavailable), "partial": True,
                            "scope_limitations": list(dict.fromkeys(
                                [*unavailable.metadata.get("scope_limitations", []), str(unavailable)]
                            )),
                        },
                    )
                    raise
            capability_gate = validate_query_execution(
                executed_entry,
                probe,
                trace_sha256=trace_sha256,
                allow_unverified=args.allow_unverified,
                schema_tables=verify_manifest_schema(
                    executed_entry,
                    args.trace,
                    trace_processor=trace_processor,
                    timeout=args.timeout,
                    max_output_bytes=args.max_output_bytes,
                ),
            )
            scope, identity = bind_manifest_process_scope(
                binding_entries, params, supplied, identity_result=gate.evidence(),
                trace=resolved_trace, trace_sha256=trace_sha256, trace_side=args.trace_side,
                trace_processor=trace_processor, timeout=args.timeout, max_output_bytes=args.max_output_bytes,
                identity_scope=gate.scope, identity_owner=identity_gate,
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
            sql = include_modules_sql(args.module) + "\n" + sql
        result = run_query(
            args.trace,
            sql=sql,
            trace_processor=trace_processor,
            timeout=args.timeout,
            max_output_bytes=args.max_output_bytes,
        )
        rows = query_rows(result)
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
            write_query_evidence(
                args, manifest_entry, processor_identity, executed_entry=executed_entry, sql=sql, rows=rows,
                capability_gate=capability_gate,
                identity=identity if identity is not None else {"status": "not_checked", "policy": "none"},
                receipt=manifest_process_scope_receipt(binding_entries),
                scope=scope_evidence(
                    binding_entries[-1][0].get("process_scope") if binding_entries else None,
                    gate_scope, str(manifest_entry.get("step_id")), rows,
                    trace_sha256=trace_sha256, trace_side=args.trace_side,
                ),
                status="observed" if rows else "empty",
            )
        return 0
    except (OSError, json.JSONDecodeError, ValueError, RuntimeError) as exc:
        code = getattr(exc, "code", None)
        print(f"error: {code}: {exc}" if isinstance(code, str) else f"error: {exc}", file=sys.stderr)
        return 2
    finally:
        sessions.close()


if __name__ == "__main__":
    raise SystemExit(main())

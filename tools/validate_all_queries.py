#!/usr/bin/env python3
"""Validate every portable query and execute owned semantic assertions safely."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import tempfile

try:
    from tools.overlays import load_overlays
except ModuleNotFoundError:  # Direct script execution.
    from overlays import load_overlays


ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "skills/perfetto-performance-analysis/references/generated"
SCRIPTS = ROOT / "skills/perfetto-performance-analysis/scripts"
PARAMETER = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?:[^}]*)\}")
ANDROID_APIS = {str(api) for api in range(28, 38)}
COMPATIBILITY_STATUSES = {"verified", "capability_gated"}
SEMANTIC_PREPARE_ERRORS = (
    "no such table:",
    "no such column:",
    "no such function:",
    "ambiguous column name:",
)

sys.path.insert(0, str(SCRIPTS))
try:
    from perfetto_sql_guardrails import analyze_sql
finally:
    sys.path.remove(str(SCRIPTS))


def validate_sql_syntax(
    sql: str, result_dependencies: list[str] | tuple[str, ...] = ()
) -> list[str]:
    """Parse portable SQL without treating missing trace schema as syntax failure."""
    result_names = set(result_dependencies)
    rendered = PARAMETER.sub(
        lambda match: (
            f"__result_{match.group(1)}" if match.group(1) in result_names else "NULL"
        ),
        sql,
    )
    rendered = re.sub(r"\$table\b", "__perfetto_macro_table", rendered)
    rendered = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", "NULL", rendered)
    rendered = re.sub(r"\b([A-Za-z_][A-Za-z0-9_]*)!\(", r"\1(", rendered)
    rendered = re.sub(
        r"INCLUDE\s+PERFETTO\s+MODULE\s+[A-Za-z_][A-Za-z0-9_.]*\s*;",
        "",
        rendered,
        flags=re.IGNORECASE,
    )
    rendered = re.sub(
        r"CREATE\s+OR\s+REPLACE\s+PERFETTO\s+(TABLE|VIEW|INDEX)",
        r"CREATE \1",
        rendered,
        flags=re.IGNORECASE,
    )
    rendered = re.sub(
        r"CREATE\s+PERFETTO\s+(TABLE|VIEW|INDEX)",
        r"CREATE \1",
        rendered,
        flags=re.IGNORECASE,
    )
    statements: list[str] = []
    pending = ""
    for line in rendered.splitlines(keepends=True):
        pending += line
        if sqlite3.complete_statement(pending):
            statements.append(pending.strip())
            pending = ""
    if pending.strip():
        statements.append(pending.strip() + ";")
    errors = []
    with sqlite3.connect(":memory:") as database:
        for statement in statements:
            if not statement or statement == ";":
                continue
            definition_source = re.sub(
                r"\A(?:\s*(?:--[^\n]*(?:\n|$)|/\*.*?\*/))*\s*",
                "",
                statement,
                flags=re.DOTALL,
            )
            definition = re.match(
                r"^CREATE\s+(?:OR\s+REPLACE\s+)?PERFETTO\s+"
                r"(?:FUNCTION|MACRO)\b.*?\bRETURNS\b.*?\bAS\s+(.*);?$",
                definition_source,
                flags=re.IGNORECASE | re.DOTALL,
            )
            if definition:
                statement = definition.group(1).strip().removesuffix(";").strip()
                if statement.startswith("(") and statement.endswith(")"):
                    statement = statement[1:-1].strip()
                if not re.match(r"^(?:SELECT|WITH)\b", statement, re.IGNORECASE):
                    statement = "SELECT " + statement
            try:
                database.execute("EXPLAIN " + statement)
            except sqlite3.Error as error:
                message = str(error)
                if not message.startswith(SEMANTIC_PREPARE_ERRORS):
                    errors.append(message)
    return errors


def validate_query(
    query: dict[str, object],
    generated_root: Path,
    *,
    stdlib_modules: set[str],
    fixtures: set[str],
    semantic_queries: set[str],
    query_ids: set[str] | None = None,
    required_symbols: set[str] | None = None,
    result_names: set[str] | None = None,
) -> dict[str, object]:
    query_id = query.get("id")
    errors: list[str] = []
    if not isinstance(query_id, str) or "/" not in query_id:
        errors.append("invalid query id")
    path_value = query.get("path")
    sql_path = generated_root / str(path_value)
    guardrail_findings: list[dict[str, object]] = []
    if not sql_path.is_file():
        errors.append("SQL path is missing")
        sql = ""
    else:
        payload = sql_path.read_bytes()
        sql = payload.decode("utf-8")
        actual = hashlib.sha256(payload).hexdigest()
        if actual != query.get("sha256"):
            errors.append("SQL hash mismatch")
        template_value = query.get("template")
        result_dependencies_value = (
            template_value.get("result_dependencies", [])
            if isinstance(template_value, dict)
            else []
        )
        syntax_errors = validate_sql_syntax(sql, result_dependencies_value)
        if syntax_errors:
            errors.append(f"SQL syntax invalid: {syntax_errors[0]}")
        guardrail_findings = [issue.to_dict() for issue in analyze_sql(sql)]
        errors.extend(
            f"SQL guardrail {finding['rule_id']}: {finding['message']}"
            for finding in guardrail_findings
            if finding["severity"] == "error"
        )
    dependencies = query.get("sql_dependencies")
    modules = (
        dependencies.get("declared_modules", [])
        if isinstance(dependencies, dict)
        else []
    )
    missing_modules = sorted(set(modules) - stdlib_modules)
    if missing_modules:
        errors.append(f"unknown stdlib module: {', '.join(missing_modules)}")
    required_tables = (
        dependencies.get("required_tables", []) if isinstance(dependencies, dict) else []
    )
    if not isinstance(required_tables, list) or not all(
        isinstance(table, str) and table for table in required_tables
    ):
        errors.append("required_tables must contain non-empty strings")
    elif required_symbols is not None:
        missing_tables = sorted(set(required_tables) - required_symbols)
        if missing_tables:
            errors.append(f"unknown required table: {', '.join(missing_tables)}")

    template = query.get("template")
    template = template if isinstance(template, dict) else {}
    parameters = template.get("parameters", [])
    if not isinstance(parameters, list) or not all(isinstance(item, str) for item in parameters):
        errors.append("template parameters must be strings")
    result_dependencies = template.get("result_dependencies", [])
    expected_parameters = set(PARAMETER.findall(sql)) - set(result_dependencies)
    if isinstance(parameters, list) and set(parameters) != expected_parameters:
        errors.append("template parameters do not match SQL placeholders")
    fragments = template.get("fragments", [])
    if not isinstance(fragments, list):
        errors.append("template fragments must be a list")
    else:
        for fragment in fragments:
            if not isinstance(fragment, dict) or not isinstance(fragment.get("source_path"), str):
                errors.append("invalid template fragment metadata")
                continue
            fragment_path = (
                generated_root
                / "runtime/fragments"
                / Path(fragment["source_path"]).name
            )
            if not fragment_path.is_file():
                errors.append(f"template fragment is missing: {fragment_path.name}")
            elif hashlib.sha256(fragment_path.read_bytes()).hexdigest() != fragment.get(
                "source_sha256"
            ):
                errors.append(f"template fragment hash mismatch: {fragment_path.name}")
    if query_ids is not None and isinstance(query_id, str):
        setup_queries = (
            dependencies.get("setup_queries", [])
            if isinstance(dependencies, dict)
            else []
        )
        for dependency in setup_queries:
            if dependency not in query_ids:
                errors.append(f"unknown setup query: {dependency}")
        for dependency in result_dependencies:
            if result_names is not None and dependency not in result_names:
                errors.append(f"unknown result dependency: {dependency}")

    compatibility = query.get("compatibility")
    android = compatibility.get("android") if isinstance(compatibility, dict) else None
    if not isinstance(android, dict) or set(android) != ANDROID_APIS:
        errors.append("Android API compatibility must cover API 28 through 37")
    elif any(
        not isinstance(entry, dict) or entry.get("status") not in COMPATIBILITY_STATUSES
        for entry in android.values()
    ):
        errors.append("invalid Android API compatibility status")
    validation = query.get("validation")
    validation = validation if isinstance(validation, dict) else {}
    declared_fixtures = set(validation.get("fixtures", []))
    missing_fixtures = sorted(declared_fixtures - fixtures)
    if missing_fixtures:
        errors.append(f"unknown owned fixture: {', '.join(missing_fixtures)}")
    semantic_verified = bool(validation.get("semantic_verified"))
    if semantic_verified and query_id not in semantic_queries:
        semantic_verified = False
        errors.append("semantic_verified has no owned assertion")
    if semantic_verified and not declared_fixtures:
        semantic_verified = False
        errors.append("semantic_verified has no declared fixture")
    return {
        "id": query_id,
        "static_valid": not errors,
        "runtime_compatible": validation.get("runtime_compatible"),
        "execution_verified": bool(validation.get("execution_verified")),
        "semantic_verified": semantic_verified,
        "guardrail_findings": guardrail_findings,
        "errors": errors,
    }


def _assert_rows(rows: list[dict[str, object]], assertion: dict[str, object]) -> None:
    if not rows:
        raise AssertionError("query returned no rows")
    field = assertion.get("field")
    kind = assertion.get("kind")
    if kind == "field_equals":
        if rows[0].get(field) != assertion.get("value"):
            raise AssertionError(f"{field} did not equal expected value")
    elif kind == "field_positive":
        if not isinstance(rows[0].get(field), (int, float)) or rows[0][field] <= 0:
            raise AssertionError(f"{field} was not positive")
    elif kind == "non_empty":
        if field not in rows[0] or rows[0][field] in (None, "", [], {}):
            raise AssertionError(f"{field} was empty")
    else:
        raise AssertionError(f"unsupported assertion kind: {kind}")


def execute_assertions(
    manifest: dict[str, object],
    fixture_root: Path,
    processor: Path,
    *,
    offline: bool,
    allow_unsupported_processor: bool = False,
) -> dict[str, dict[str, object]]:
    results: dict[str, dict[str, object]] = {}
    with tempfile.TemporaryDirectory() as temporary:
        for fixture in manifest["fixtures"]:
            trace = fixture_root / fixture["path"]
            if not trace.is_file():
                if offline:
                    continue
                raise FileNotFoundError(f"owned fixture is missing: {fixture['id']}")
            if hashlib.sha256(trace.read_bytes()).hexdigest() != fixture["sha256"]:
                raise ValueError(f"owned fixture hash mismatch: {fixture['id']}")
            for assertion in fixture["assertions"]:
                output = Path(temporary) / f"{assertion['id']}.json"
                command = [
                    sys.executable,
                    str(SCRIPTS / "perfetto_query.py"),
                    str(trace),
                    "--query-id",
                    assertion["query_id"],
                    "--trace-processor",
                    str(processor),
                    "--output",
                    str(output),
                ]
                for name, value in sorted(assertion.get("params", {}).items()):
                    command.extend(("--param", f"{name}={json.dumps(value)}"))
                if allow_unsupported_processor:
                    command.append("--allow-unsupported-processor")
                completed = subprocess.run(
                    command,
                    cwd=ROOT,
                    check=False,
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                if completed.returncode != 0:
                    raise RuntimeError(
                        f"semantic assertion failed to execute: {assertion['id']}: "
                        f"{completed.stderr[-2000:]}"
                    )
                if output.stat().st_size > 10 * 1024 * 1024:
                    raise RuntimeError(f"semantic assertion output too large: {assertion['id']}")
                rows = json.loads(output.read_text(encoding="utf-8"))
                _assert_rows(rows, assertion)
                results[assertion["id"]] = {
                    "query_id": assertion["query_id"],
                    "fixture_id": fixture["id"],
                    "fixture_sha256": fixture["sha256"],
                    "processor": str(processor),
                    "passed": True,
                }
    return results


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated", type=Path, default=GENERATED)
    parser.add_argument("--manifest", type=Path, default=ROOT / "fixtures/manifest.json")
    parser.add_argument(
        "--stdlib-index",
        type=Path,
        default=ROOT / "upstreams/snapshots/google-perfetto/stdlib-index.json",
    )
    parser.add_argument("--overrides", type=Path, default=ROOT / "src/overrides")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument(
        "--allow-unsupported-processor",
        action="store_true",
        help="Canary-only: execute against a processor not present in the release lock",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "test-output/all-query-validation.json",
    )
    args = parser.parse_args(arguments)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    fixture_ids = {fixture["id"] for fixture in manifest["fixtures"]}
    assertion_ids = {
        assertion["id"]
        for fixture in manifest["fixtures"]
        for assertion in fixture["assertions"]
    }
    semantic_queries = {
        assertion["query_id"]
        for fixture in manifest["fixtures"]
        for assertion in fixture["assertions"]
    }
    stdlib = json.loads(args.stdlib_index.read_text(encoding="utf-8"))
    stdlib_modules = {module["module"] for module in stdlib["modules"]}
    runtime_symbols = json.loads(
        (args.generated / "runtime/stdlib-symbols.json").read_text(encoding="utf-8")
    )
    required_symbols = set(runtime_symbols["builtins"])
    required_symbols.update(
        symbol["name"]
        for module in stdlib["modules"]
        for symbol in module["symbols"]
    )
    index = json.loads((args.generated / "runtime/sql-index.json").read_text(encoding="utf-8"))
    skill_index = json.loads(
        (args.generated / "runtime/skill-index.json").read_text(encoding="utf-8")
    )
    result_names_by_skill = {}
    for skill_id, relative_path in skill_index["skills"].items():
        skill = json.loads((args.generated / "runtime" / relative_path).read_text(encoding="utf-8"))
        result_names_by_skill[skill_id] = {
            step.get("save_as", step.get("id"))
            for step in skill.get("steps", [])
            if isinstance(step, dict) and isinstance(step.get("id"), str)
        }
    descriptors = []
    seen: set[str] = set()
    for shard_name in index["shards"]:
        shard = json.loads(
            (args.generated / "runtime" / shard_name).read_text(encoding="utf-8")
        )
        for query in shard["queries"]:
            if query["id"] in seen:
                raise ValueError(f"duplicate query id: {query['id']}")
            seen.add(query["id"])
            descriptors.append(query)
    queries = [
        validate_query(
            query,
            args.generated,
            stdlib_modules=stdlib_modules,
            fixtures=fixture_ids,
            semantic_queries=semantic_queries,
            query_ids=seen,
            required_symbols=required_symbols,
            result_names=result_names_by_skill.get(query["skill_id"], set()),
        )
        for query in descriptors
    ]
    packaged_fragments = {
        path.name for path in (args.generated / "runtime/fragments").glob("*.sql")
    }
    referenced_fragments = {
        Path(fragment["source_path"]).name
        for query in descriptors
        for fragment in query.get("template", {}).get("fragments", [])
    }
    overlay_errors = []
    if packaged_fragments != referenced_fragments:
        overlay_errors.append(
            "runtime fragment coverage differs: "
            f"unreferenced={sorted(packaged_fragments - referenced_fragments)}, "
            f"missing={sorted(referenced_fragments - packaged_fragments)}"
        )
    for overlay in load_overlays(args.overrides):
        missing = sorted(set(overlay.regression_ids) - assertion_ids)
        if missing:
            overlay_errors.append(
                f"{overlay.target}: stale regression ids: {', '.join(missing)}"
            )

    executed = {}
    if args.execute:
        fixture_root_value = os.environ.get("PERFETTO_FIXTURE_ROOT")
        processor_value = os.environ.get("PERFETTO_TRACE_PROCESSOR")
        if not fixture_root_value or not processor_value:
            raise RuntimeError(
                "--execute requires PERFETTO_FIXTURE_ROOT and PERFETTO_TRACE_PROCESSOR"
            )
        executed = execute_assertions(
            manifest,
            Path(fixture_root_value),
            Path(processor_value),
            offline=os.environ.get("PERFETTO_FIXTURE_TIER") == "offline",
            allow_unsupported_processor=args.allow_unsupported_processor,
        )
    report = {
        "schema_version": 1,
        "summary": {
            "queries": len(queries),
            "static_valid": sum(bool(query["static_valid"]) for query in queries),
            "runtime_compatible": sum(query["runtime_compatible"] is True for query in queries),
            "execution_verified": sum(bool(query["execution_verified"]) for query in queries),
            "semantic_verified": sum(bool(query["semantic_verified"]) for query in queries),
            "semantic_assertions_executed": len(executed),
        },
        "queries": queries,
        "executed_assertions": executed,
        "overlay_errors": overlay_errors,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    errors = [error for query in queries for error in query["errors"]]
    if errors or overlay_errors:
        print(
            f"query validation failed: {len(errors)} query errors, "
            f"{len(overlay_errors)} overlay errors"
        )
        return 1
    print(json.dumps(report["summary"], indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

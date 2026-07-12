#!/usr/bin/env python3
"""Compile immutable SmartPerfetto base content plus reviewed local overlays."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from pathlib import PurePosixPath
import shutil
import tempfile

try:
    from tools.overlays import Overlay, load_overlays
except ModuleNotFoundError:  # Direct script execution.
    from overlays import Overlay, load_overlays


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE = ROOT / "upstreams/snapshots/smartperfetto/base/references/generated"
DEFAULT_OVERRIDES = ROOT / "src/overrides"
DEFAULT_OUTPUT = ROOT / "skills/perfetto-performance-analysis/references/generated"
DEFAULT_FIXTURE_MANIFEST = ROOT / "fixtures/manifest.json"
DEFAULT_NATIVE_MANIFEST = ROOT / "src/native-manifest.json"
DEFAULT_SYMBOL_ALIASES = ROOT / "src/symbol-aliases.json"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _refresh_sql_query_hashes(compiled: Path, overlay: Overlay) -> None:
    if not overlay.target.startswith("sql/"):
        raise ValueError(f"SQL overlay target must be generated SQL: {overlay.target}")
    query_path = overlay.target
    query_root = compiled / "runtime/queries"
    matched = 0
    for shard in sorted(query_root.glob("*.json")):
        data = json.loads(shard.read_text(encoding="utf-8"))
        changed = False
        for query in data.get("queries", []):
            if query.get("path") == query_path:
                query["sha256"] = overlay.replacement_sha256
                changed = True
                matched += 1
        if changed:
            shard.write_text(
                json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
    if matched != 1:
        raise ValueError(
            f"SQL overlay must match exactly one query descriptor: {overlay.target} ({matched})"
        )


def _replace_strings(value: object, replacements: dict[str, str]) -> object:
    if isinstance(value, str):
        return replacements.get(value, value)
    if isinstance(value, list):
        return [_replace_strings(item, replacements) for item in value]
    if isinstance(value, dict):
        return {key: _replace_strings(item, replacements) for key, item in value.items()}
    return value


def _apply_owned_fixture_manifest(compiled: Path, owned_manifest_path: Path) -> None:
    runtime_manifest_path = compiled / "runtime/fixture-manifest.json"
    imported = json.loads(runtime_manifest_path.read_text(encoding="utf-8"))
    owned = json.loads(owned_manifest_path.read_text(encoding="utf-8"))
    owned_by_hash = {fixture["sha256"]: fixture["id"] for fixture in owned["fixtures"]}
    replacements = {
        fixture["id"]: owned_by_hash[fixture["sha256"]]
        for fixture in imported["fixtures"]
        if fixture["sha256"] in owned_by_hash
    }
    if len(replacements) != len(imported["fixtures"]):
        raise ValueError("owned fixture manifest does not cover every imported fixture")
    runtime_manifest_path.write_text(
        json.dumps(owned, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    for path in sorted((compiled / "runtime").rglob("*.json")):
        if path == runtime_manifest_path:
            continue
        value = json.loads(path.read_text(encoding="utf-8"))
        replaced = _replace_strings(value, replacements)
        if replaced != value:
            path.write_text(
                json.dumps(replaced, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )


def _safe_relative(value: object) -> bool:
    if not isinstance(value, str) or not value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and path.as_posix() == value


def _uses_symlink(path: Path, boundary: Path) -> bool:
    current = path
    while current != boundary:
        if current.is_symlink():
            return True
        if current.parent == current:
            return True
        current = current.parent
    return boundary.is_symlink()


def _apply_native_assets(compiled: Path, native_manifest_path: Path) -> None:
    manifest = json.loads(native_manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or not isinstance(manifest.get("assets"), list):
        raise ValueError("invalid native asset manifest")
    src_root = native_manifest_path.parent
    seen_targets: set[str] = set()
    for asset in manifest["assets"]:
        kind = asset.get("kind")
        source_value = asset.get("source")
        target_value = asset.get("target")
        if kind not in {"skill", "strategy", "sql"}:
            raise ValueError(f"invalid native asset kind: {kind}")
        if not _safe_relative(source_value) or not _safe_relative(target_value):
            raise ValueError("native asset source/target must be safe relative paths")
        if target_value in seen_targets or (compiled / target_value).exists():
            raise ValueError(f"native asset target collides with imported content: {target_value}")
        seen_targets.add(target_value)
        source = src_root / source_value
        resolved_source = source.resolve()
        if (
            not resolved_source.is_relative_to(src_root.resolve())
            or _uses_symlink(source, src_root)
            or not source.is_file()
            or _sha256(source) != asset.get("sha256")
        ):
            raise ValueError(f"native asset hash mismatch: {source_value}")
        target = compiled / target_value
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        if kind == "skill":
            data = json.loads(source.read_text(encoding="utf-8"))
            skill_id = data.get("id")
            expected_target = f"runtime/skills/{skill_id}.json"
            if not isinstance(skill_id, str) or target_value != expected_target:
                raise ValueError(f"native Skill target must be {expected_target}")
            index_path = compiled / "runtime/skill-index.json"
            index = json.loads(index_path.read_text(encoding="utf-8"))
            if skill_id in index["skills"]:
                raise ValueError(f"native Skill id collides with imported Skill: {skill_id}")
            index["skills"][skill_id] = f"skills/{skill_id}.json"
            index_path.write_text(
                json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
        elif kind == "strategy":
            descriptor = asset.get("index_entry")
            if not isinstance(descriptor, dict):
                raise ValueError("native Strategy requires index_entry")
            index_path = compiled / "runtime/strategy-index.json"
            index = json.loads(index_path.read_text(encoding="utf-8"))
            destination = f"references/generated/{target_value}"
            if any(item.get("destination") == destination for item in index["strategies"]):
                raise ValueError(f"native Strategy destination collides: {destination}")
            index["strategies"].append(
                {
                    **descriptor,
                    "destination": destination,
                    "source_path": f"src/{source_value}",
                    "source_sha256": asset["sha256"],
                    "status": "native",
                }
            )
            index["strategies"].sort(key=lambda item: str(item.get("source_path")))
            index_path.write_text(
                json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
        else:
            descriptor_value = asset.get("query_descriptor")
            if not _safe_relative(descriptor_value):
                raise ValueError("native SQL requires a safe query_descriptor")
            descriptor_path = src_root / descriptor_value
            if (
                not descriptor_path.resolve().is_relative_to(src_root.resolve())
                or _uses_symlink(descriptor_path, src_root)
            ):
                raise ValueError("native SQL query descriptor cannot be a symlink")
            descriptor = json.loads(descriptor_path.read_text(encoding="utf-8"))
            query = descriptor.get("query")
            if not isinstance(query, dict) or query.get("path") != target_value:
                raise ValueError("native SQL query descriptor path mismatch")
            if query.get("sha256") != asset["sha256"]:
                raise ValueError("native SQL query descriptor hash mismatch")
            query_id = query.get("id")
            if not isinstance(query_id, str) or "/" not in query_id:
                raise ValueError("native SQL query id is invalid")
            skill_id = query_id.split("/", 1)[0]
            shard_relative = f"queries/{skill_id}.json"
            shard = compiled / "runtime" / shard_relative
            if shard.exists():
                shard_data = json.loads(shard.read_text(encoding="utf-8"))
            else:
                shard_data = {"queries": []}
            if any(item.get("id") == query_id for item in shard_data["queries"]):
                raise ValueError(f"native query id collides: {query_id}")
            shard_data["queries"].append(query)
            shard_data["queries"].sort(key=lambda item: item["id"])
            shard.write_text(
                json.dumps(shard_data, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            sql_index_path = compiled / "runtime/sql-index.json"
            sql_index = json.loads(sql_index_path.read_text(encoding="utf-8"))
            if shard_relative not in sql_index["shards"]:
                sql_index["shards"].append(shard_relative)
                sql_index["shards"].sort()
                sql_index_path.write_text(
                    json.dumps(sql_index, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8",
                )


def _rebuild_generated_metadata(compiled: Path) -> None:
    skill_index = json.loads((compiled / "runtime/skill-index.json").read_text(encoding="utf-8"))
    sql_index = json.loads((compiled / "runtime/sql-index.json").read_text(encoding="utf-8"))
    queries = []
    normalizations = []
    aliases_document = json.loads(DEFAULT_SYMBOL_ALIASES.read_text(encoding="utf-8"))
    if aliases_document.get("schema_version") != 1 or not isinstance(
        aliases_document.get("aliases"), dict
    ):
        raise ValueError("invalid local symbol alias registry")
    symbol_aliases = aliases_document["aliases"]
    for shard in sql_index["shards"]:
        shard_path = compiled / "runtime" / shard
        shard_data = json.loads(shard_path.read_text(encoding="utf-8"))
        for query in shard_data["queries"]:
            sql = (compiled / query["path"]).read_text(encoding="utf-8")
            dependencies = query.get("sql_dependencies", {})
            required_tables = dependencies.get("required_tables", [])
            normalized_tables = [symbol_aliases.get(table, table) for table in required_tables]
            if normalized_tables != required_tables:
                normalizations.append(
                    {
                        "query_id": query["id"],
                        "field": "sql_dependencies.required_tables",
                        "replacements": {
                            table: symbol_aliases[table]
                            for table in required_tables
                            if table in symbol_aliases
                        },
                        "reason": "legacy symbol normalized through src/symbol-aliases.json",
                    }
                )
                dependencies["required_tables"] = normalized_tables
            for fragment in query.get("template", {}).get("fragments", []):
                fragment_path = compiled / "runtime/fragments" / Path(fragment["source_path"]).name
                packaged_sha256 = _sha256(fragment_path)
                if fragment.get("source_sha256") != packaged_sha256:
                    normalizations.append(
                        {
                            "query_id": query["id"],
                            "field": f"template.fragments.{fragment_path.name}.source_sha256",
                            "reason": "hash identifies the packaged runtime fragment",
                        }
                    )
                    fragment["source_sha256"] = packaged_sha256
        shard_path.write_text(
            json.dumps(shard_data, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        queries.extend(shard_data["queries"])
    (compiled / "runtime/compiler-normalizations.json").write_text(
        json.dumps(
            {"schema_version": 1, "normalizations": normalizations},
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    report_path = compiled / "runtime/sql-validation-report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report["execution_verified_queries"] = sorted(
        query["id"] for query in queries if query.get("validation", {}).get("execution_verified")
    )
    report["semantic_verified_queries"] = sorted(
        query["id"] for query in queries if query.get("validation", {}).get("semantic_verified")
    )
    report["summary"] = {
        "queries": len(queries),
        "static_valid": sum(
            bool(query.get("validation", {}).get("static_valid")) for query in queries
        ),
        "execution_verified": len(report["execution_verified_queries"]),
        "semantic_verified": len(report["semantic_verified_queries"]),
        "capability_gated": sum(
            query.get("validation", {}).get("default_execution") == "capability_gate_required"
            for query in queries
        ),
    }
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    catalog_path = compiled / "catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    catalog.update(
        {
            "runtime_skills": len(skill_index["skills"]),
            "runtime_queries": len(queries),
            "sql_files": sum(1 for _ in (compiled / "sql").rglob("*.sql")),
            "generated_files": sum(1 for path in compiled.rglob("*") if path.is_file()),
        }
    )
    catalog_path.write_text(
        json.dumps(catalog, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def compile_tree(
    base: Path,
    overrides: Path,
    output: Path,
    *,
    owned_fixture_manifest: Path | None = None,
    native_manifest: Path | None = None,
) -> Path:
    base = base.expanduser().resolve()
    output = output.expanduser().resolve()
    if not base.is_dir():
        raise FileNotFoundError(base)
    for path in base.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"base tree contains symlink: {path}")
    overlays = load_overlays(overrides)
    temporary = Path(tempfile.mkdtemp(prefix=".compile-", dir=output.parent))
    shutil.rmtree(temporary)
    try:
        shutil.copytree(base, temporary)
        for overlay in overlays:
            base_target = base / overlay.target
            if not base_target.is_file():
                raise ValueError(f"overlay base target does not exist: {overlay.target}")
            if _sha256(base_target) != overlay.expected_base_sha256:
                raise ValueError(f"stale overlay base hash: {overlay.target}")
            target = temporary / overlay.target
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(overlay.replacement, target)
            for (
                dependent_target,
                dependent_source,
                _,
                expected_dependent_sha256,
            ) in overlay.dependent_replacements:
                dependent = temporary / dependent_target
                if not dependent.is_file():
                    raise ValueError(
                        f"overlay dependent target does not exist: {dependent_target}"
                    )
                if _sha256(dependent) != expected_dependent_sha256:
                    raise ValueError(
                        f"stale overlay dependent base hash: {dependent_target}"
                    )
                shutil.copyfile(dependent_source, dependent)
            if overlay.kind == "sql":
                _refresh_sql_query_hashes(temporary, overlay)
        if native_manifest is not None:
            _apply_native_assets(temporary, native_manifest)
        if owned_fixture_manifest is not None:
            _apply_owned_fixture_manifest(temporary, owned_fixture_manifest)
        if (temporary / "catalog.json").is_file():
            _rebuild_generated_metadata(temporary)
        if output.exists():
            backup = output.with_name(f".{output.name}.previous")
            if backup.exists():
                shutil.rmtree(backup)
            os.replace(output, backup)
            try:
                os.replace(temporary, output)
            except BaseException:
                os.replace(backup, output)
                raise
            shutil.rmtree(backup)
        else:
            os.replace(temporary, output)
        return output
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


def _trees_equal(left: Path, right: Path) -> bool:
    left_files = {path.relative_to(left) for path in left.rglob("*") if path.is_file()}
    right_files = {path.relative_to(right) for path in right.rglob("*") if path.is_file()}
    return left_files == right_files and all(
        (left / path).read_bytes() == (right / path).read_bytes() for path in left_files
    )


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=DEFAULT_BASE)
    parser.add_argument("--overrides", type=Path, default=DEFAULT_OVERRIDES)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--fixture-manifest", type=Path, default=DEFAULT_FIXTURE_MANIFEST
    )
    parser.add_argument("--native-manifest", type=Path, default=DEFAULT_NATIVE_MANIFEST)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    args = parser.parse_args(arguments)
    if args.apply:
        compile_tree(
            args.base,
            args.overrides,
            args.output,
            owned_fixture_manifest=args.fixture_manifest,
            native_manifest=args.native_manifest,
        )
        print(f"compiled Skill tree: {args.output}")
        return 0
    with tempfile.TemporaryDirectory() as temporary:
        candidate = Path(temporary) / "skill"
        compile_tree(
            args.base,
            args.overrides,
            candidate,
            owned_fixture_manifest=args.fixture_manifest,
            native_manifest=args.native_manifest,
        )
        if not _trees_equal(candidate, args.output):
            raise SystemExit("compiled Skill tree differs; run with --apply")
    print("compiled Skill tree is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

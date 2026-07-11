#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.export_from_smartperfetto import PUBLIC_SKILL, WORKFLOWS


SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40,64}$")


class CatalogValidationError(RuntimeError):
    pass


def require_mapping(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CatalogValidationError(f"{label} must be an object")
    return value


def require_list(value: object, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise CatalogValidationError(f"{label} must be an array")
    return value


def require_sha256(value: object, label: str) -> None:
    if not isinstance(value, str) or not SHA256_PATTERN.fullmatch(value):
        raise CatalogValidationError(f"{label} must be a lowercase SHA-256")


def require_unique(entries: list[dict[str, Any]], key: str, label: str) -> None:
    values = [entry.get(key) for entry in entries if entry.get(key) is not None]
    duplicates = sorted(
        str(value) for value, count in Counter(values).items() if count > 1
    )
    if duplicates:
        raise CatalogValidationError(f"duplicate {label}: {duplicates}")


def validate_destination(destination: object, skill_root: Path, label: str) -> None:
    if not isinstance(destination, str) or not destination:
        raise CatalogValidationError(f"{label} destination is required")
    relative = Path(destination)
    if relative.is_absolute() or ".." in relative.parts:
        raise CatalogValidationError(f"{label} destination must stay inside the Skill")
    root = skill_root.resolve()
    resolved = (root / relative).resolve()
    if resolved != root and root not in resolved.parents:
        raise CatalogValidationError(f"{label} destination escapes the Skill")
    if not resolved.is_file():
        raise CatalogValidationError(f"generated destination is missing: {destination}")


def validate_catalog(catalog: dict[str, Any], skill_root: Path) -> None:
    if catalog.get("schema_version") != 1:
        raise CatalogValidationError("unsupported catalog schema_version")
    if catalog.get("public_skill") != PUBLIC_SKILL:
        raise CatalogValidationError("catalog public_skill does not match")

    source = require_mapping(catalog.get("source"), "source")
    if source.get("dirty") is not False:
        raise CatalogValidationError("catalog source must be a clean committed checkout")
    commit = source.get("commit")
    if not isinstance(commit, str) or not COMMIT_PATTERN.fullmatch(commit):
        raise CatalogValidationError("source.commit must be a Git object id")
    require_sha256(source.get("policy_sha256"), "source.policy_sha256")

    skills = [
        require_mapping(entry, f"skills[{index}]")
        for index, entry in enumerate(require_list(catalog.get("skills"), "skills"))
    ]
    strategies = [
        require_mapping(entry, f"strategies[{index}]")
        for index, entry in enumerate(
            require_list(catalog.get("strategies"), "strategies")
        )
    ]
    pipeline_docs = [
        require_mapping(entry, f"pipeline_docs[{index}]")
        for index, entry in enumerate(
            require_list(catalog.get("pipeline_docs"), "pipeline_docs")
        )
    ]

    require_unique(skills, "name", "Skill name")
    all_entries = skills + strategies + pipeline_docs
    require_unique(all_entries, "source_path", "source path")
    exported = [
        entry for entry in all_entries if entry.get("disposition") != "product-only"
    ]
    require_unique(exported, "destination", "destination")

    for index, entry in enumerate(skills):
        label = f"Skill {entry.get('name', index)}"
        if not isinstance(entry.get("name"), str) or not entry["name"]:
            raise CatalogValidationError(f"{label} name is required")
        if entry.get("disposition") not in {"exported", "merged", "product-only"}:
            raise CatalogValidationError(f"{label} has invalid disposition")
        require_sha256(entry.get("source_sha256"), f"{label} source_sha256")
        if entry.get("disposition") == "product-only":
            if not entry.get("reason"):
                raise CatalogValidationError(f"{label} product-only reason is required")
            continue
        if entry.get("workflow") not in WORKFLOWS:
            raise CatalogValidationError(f"{label} has invalid workflow")
        validate_destination(entry.get("destination"), skill_root, label)

    for collection_name, entries in (
        ("strategy", strategies),
        ("pipeline doc", pipeline_docs),
    ):
        for index, entry in enumerate(entries):
            label = f"{collection_name} {entry.get('source_path', index)}"
            require_sha256(entry.get("source_sha256"), f"{label} source_sha256")
            if entry.get("disposition") == "product-only":
                if not entry.get("reason"):
                    raise CatalogValidationError(
                        f"{label} product-only reason is required"
                    )
                continue
            if entry.get("disposition") not in {"exported", "merged"}:
                raise CatalogValidationError(f"{label} has invalid disposition")
            if collection_name == "strategy" and entry.get("workflow") not in WORKFLOWS:
                raise CatalogValidationError(f"{label} has invalid workflow")
            validate_destination(entry.get("destination"), skill_root, label)

    summary = require_mapping(catalog.get("summary"), "summary")
    runtime_types = Counter(str(entry.get("runtime_type")) for entry in skills)
    expected = {
        "runtime_candidates": len(skills),
        "strategy_sources": len(strategies),
        "exported_strategy_sources": sum(
            entry.get("disposition") != "product-only" for entry in strategies
        ),
        "product_only_strategy_sources": sum(
            entry.get("disposition") == "product-only" for entry in strategies
        ),
        "pipeline_docs": len(pipeline_docs),
    }
    for key, value in expected.items():
        if summary.get(key) != value:
            raise CatalogValidationError(
                f"summary.{key} is {summary.get(key)!r}; expected {value}"
            )
    if summary.get("runtime_types") != dict(sorted(runtime_types.items())):
        raise CatalogValidationError("summary.runtime_types does not match Skills")
    skill_yaml_files = summary.get("skill_yaml_files")
    excluded = summary.get("excluded_skill_definitions")
    if not isinstance(skill_yaml_files, int) or not isinstance(excluded, int):
        raise CatalogValidationError("summary Skill file counts must be integers")
    if skill_yaml_files != len(skills) + excluded:
        raise CatalogValidationError("summary Skill file counts do not add up")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate the generated Skill catalog.")
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--skill-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        raw = json.loads(args.catalog.read_text(encoding="utf-8"))
        catalog = require_mapping(raw, "catalog")
        validate_catalog(catalog, args.skill_root)
    except (OSError, json.JSONDecodeError, CatalogValidationError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    print(f"Catalog is valid: {args.catalog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

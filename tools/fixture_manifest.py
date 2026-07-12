#!/usr/bin/env python3
"""Validation helpers for project-owned real trace fixtures."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from typing import Any


SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")
REQUIRED_FIELDS = (
    "id",
    "path",
    "sha256",
    "license",
    "origin",
    "real",
    "privacy_review",
    "capture",
    "platform",
    "capabilities",
    "assertions",
)


def load_manifest(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("fixture manifest must be a JSON object")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_safe_relative_path(value: object) -> bool:
    if not isinstance(value, str) or not value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and path.as_posix() == value


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    if manifest.get("schema_version") != 1:
        issues.append("manifest: schema_version must be 1")
    if not isinstance(manifest.get("fixture_pack_version"), str):
        issues.append("manifest: fixture_pack_version is required")
    fixtures = manifest.get("fixtures")
    if not isinstance(fixtures, list):
        return sorted([*issues, "manifest: fixtures must be a list"])

    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    assertion_ids: set[str] = set()
    for index, fixture in enumerate(fixtures):
        prefix = f"fixture[{index}]"
        if not isinstance(fixture, dict):
            issues.append(f"{prefix}: must be an object")
            continue
        for field in REQUIRED_FIELDS:
            if field not in fixture:
                issues.append(f"{prefix}: missing {field}")

        fixture_id = fixture.get("id")
        if not isinstance(fixture_id, str) or not fixture_id:
            issues.append(f"{prefix}: invalid id")
        elif fixture_id in seen_ids:
            issues.append(f"{prefix}: duplicate id {fixture_id}")
        else:
            seen_ids.add(fixture_id)

        path = fixture.get("path")
        if not _is_safe_relative_path(path):
            issues.append(f"{prefix}: unsafe path {path}")
        elif path in seen_paths:
            issues.append(f"{prefix}: duplicate path {path}")
        else:
            seen_paths.add(path)

        if not isinstance(fixture.get("sha256"), str) or not SHA256.fullmatch(
            fixture["sha256"]
        ):
            issues.append(f"{prefix}: invalid sha256")

        origin = fixture.get("origin")
        if not isinstance(origin, dict):
            issues.append(f"{prefix}: origin must be an object")
        else:
            if origin.get("redistribution_review") != "approved":
                issues.append(f"{prefix}: redistribution review must be approved")
            if not isinstance(origin.get("commit"), str) or not COMMIT.fullmatch(
                origin["commit"]
            ):
                issues.append(f"{prefix}: origin commit must be immutable")
            if not _is_safe_relative_path(origin.get("path")):
                issues.append(f"{prefix}: unsafe origin path")

        privacy = fixture.get("privacy_review")
        if not isinstance(privacy, dict) or privacy.get("status") != "passed":
            issues.append(f"{prefix}: privacy review must pass")

        assertions = fixture.get("assertions")
        if not isinstance(assertions, list):
            issues.append(f"{prefix}: assertions must be a list")
            assertions = []
        if assertions and fixture.get("real") is not True:
            issues.append(f"{prefix}: release-blocking assertions require real trace")
        for assertion_index, assertion in enumerate(assertions):
            if not isinstance(assertion, dict):
                issues.append(f"{prefix}: assertion[{assertion_index}] must be an object")
                continue
            assertion_id = assertion.get("id")
            if not isinstance(assertion_id, str) or not assertion_id:
                issues.append(f"{prefix}: assertion[{assertion_index}] missing id")
            elif assertion_id in assertion_ids:
                issues.append(f"{prefix}: duplicate assertion id {assertion_id}")
            else:
                assertion_ids.add(assertion_id)
            if not isinstance(assertion.get("query_id"), str):
                issues.append(f"{prefix}: assertion[{assertion_index}] missing query_id")

        if not isinstance(fixture.get("capture"), dict):
            issues.append(f"{prefix}: capture must be an object")
        if not isinstance(fixture.get("platform"), dict):
            issues.append(f"{prefix}: platform must be an object")
        if not isinstance(fixture.get("capabilities"), list):
            issues.append(f"{prefix}: capabilities must be a list")
    return sorted(issues)


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, nargs="?", default=Path("fixtures/manifest.json"))
    args = parser.parse_args(arguments)
    issues = validate_manifest(load_manifest(args.manifest))
    if issues:
        for issue in issues:
            print(issue)
        return 1
    print(f"fixture manifest valid: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

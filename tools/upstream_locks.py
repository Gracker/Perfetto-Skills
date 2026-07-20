#!/usr/bin/env python3
"""Validate immutable upstream locks and committed SmartPerfetto base content."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
from typing import Any


COMMIT = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
GITHUB = re.compile(r"^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


def _read(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"lock must be a JSON object: {path}")
    return value


def _require_hash(value: object, label: str, pattern: re.Pattern[str] = SHA256) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise ValueError(f"{label} must be immutable lowercase hex")
    return value


def build_generated_base(root: Path) -> dict[str, dict[str, object]]:
    root = root.expanduser().resolve()
    if not root.is_dir():
        raise FileNotFoundError(root)
    result: dict[str, dict[str, object]] = {}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"base tree may not contain symlinks: {path}")
        if not path.is_file():
            continue
        payload = path.read_bytes()
        result[path.relative_to(root).as_posix()] = {
            "sha256": hashlib.sha256(payload).hexdigest(),
            "size": len(payload),
        }
    return result


def load_and_validate_smartperfetto_lock(path: Path) -> dict[str, Any]:
    lock = _read(path)
    if lock.get("schema_version") != 1:
        raise ValueError("unsupported SmartPerfetto lock schema")
    if lock.get("repository") != "https://github.com/Gracker/SmartPerfetto":
        raise ValueError("unexpected SmartPerfetto repository")
    _require_hash(lock.get("commit"), "SmartPerfetto commit", COMMIT)
    _require_hash(lock.get("policy_sha256"), "SmartPerfetto policy hash")
    manifest_path = path.parent / str(lock.get("generated_base_manifest"))
    manifest = _read(manifest_path)
    if manifest.get("source_commit") != lock["commit"]:
        raise ValueError("generated base source commit does not match lock")
    files = manifest.get("files")
    if not isinstance(files, dict) or list(files) != sorted(files):
        raise ValueError("generated base files must be a sorted object")
    base_root = path.parent / str(lock.get("generated_base_root"))
    if build_generated_base(base_root) != files:
        raise ValueError("committed SmartPerfetto base content does not match manifest")
    return {**lock, "generated_base": files}


def load_and_validate_google_lock(
    path: Path, *, validate_snapshots: bool = True
) -> dict[str, Any]:
    lock = _read(path)
    if lock.get("schema_version") != 1:
        raise ValueError("unsupported Google Perfetto lock schema")
    repository = lock.get("repository")
    if repository != "https://github.com/google/perfetto" or not GITHUB.fullmatch(repository):
        raise ValueError("unexpected Google Perfetto repository")
    _require_hash(lock.get("commit"), "Google Perfetto commit", COMMIT)
    _require_hash(lock.get("stdlib_tree"), "Perfetto stdlib tree", COMMIT)
    if not isinstance(lock.get("tag"), str) or not re.fullmatch(r"v\d+(?:\.\d+)*", lock["tag"]):
        raise ValueError("Google Perfetto tag is invalid")
    if not isinstance(lock.get("rpc_api_version"), int) or lock["rpc_api_version"] <= 0:
        raise ValueError("Google Perfetto RPC API version is invalid")
    official = lock.get("official_skill")
    if not isinstance(official, dict) or official.get("role") != "gap_check_only":
        raise ValueError("official Skill must remain gap_check_only")
    _require_hash(official.get("sha256"), "official Skill hash")
    official_snapshot_sha256 = _require_hash(
        official.get("snapshot_sha256"), "official Skill snapshot hash"
    )
    stdlib_snapshot_sha256 = _require_hash(
        lock.get("stdlib_snapshot_sha256"), "Perfetto stdlib snapshot hash"
    )
    binary = lock.get("trace_processor")
    if not isinstance(binary, dict):
        raise ValueError("trace_processor lock metadata is required")
    if binary.get("version") != lock.get("tag"):
        raise ValueError("trace processor version does not match Perfetto tag")
    lock_path = path.parents[1] / str(binary.get("lock_path"))
    expected = _require_hash(binary.get("lock_sha256"), "trace processor lock hash")
    actual = hashlib.sha256(lock_path.read_bytes()).hexdigest()
    if actual != expected:
        raise ValueError("trace processor lock bytes do not match Google Perfetto lock")
    if not validate_snapshots:
        return lock
    official_snapshot_path = path.parent / "snapshots/google-perfetto/official-skill.json"
    if hashlib.sha256(official_snapshot_path.read_bytes()).hexdigest() != official_snapshot_sha256:
        raise ValueError("official Skill snapshot bytes differ from lock")
    official_snapshot = _read(official_snapshot_path)
    if official_snapshot.get("commit") != lock["commit"]:
        raise ValueError("official Skill snapshot commit differs from lock")
    official_files = {
        item["path"]: item["sha256"] for item in official_snapshot.get("files", [])
    }
    if official_files.get(official.get("path")) != official.get("sha256"):
        raise ValueError("official Skill snapshot hash differs from lock")
    stdlib_snapshot_path = path.parent / "snapshots/google-perfetto/stdlib-index.json"
    if hashlib.sha256(stdlib_snapshot_path.read_bytes()).hexdigest() != stdlib_snapshot_sha256:
        raise ValueError("Perfetto stdlib snapshot bytes differ from lock")
    stdlib_snapshot = _read(stdlib_snapshot_path)
    if (
        stdlib_snapshot.get("commit") != lock["commit"]
        or stdlib_snapshot.get("stdlib_tree") != lock["stdlib_tree"]
        or stdlib_snapshot.get("parse_warnings") != []
    ):
        raise ValueError("Perfetto stdlib snapshot differs from lock")
    return lock


def load_and_validate_android_skills_lock(path: Path) -> dict[str, Any]:
    lock = _read(path)
    if lock.get("schema_version") != 2:
        raise ValueError("unsupported Android Skills lock schema")
    expected_keys = {
        "commit",
        "repository",
        "role",
        "schema_version",
        "subtrees",
        "tracked_ref",
        "trees",
    }
    if set(lock) != expected_keys:
        if {"snapshot_path", "snapshot_sha256"} & set(lock):
            raise ValueError("Android Skills gap-check locks must not persist snapshots")
        raise ValueError("Android Skills lock fields are invalid")
    if (path.parent / "snapshots/android-skills").exists():
        raise ValueError("Android Skills gap-check inputs must not persist snapshots")
    repository = lock.get("repository")
    if repository != "https://github.com/android/skills" or not GITHUB.fullmatch(
        repository
    ):
        raise ValueError("unexpected Android Skills repository")
    _require_hash(lock.get("commit"), "Android Skills commit", COMMIT)
    if lock.get("role") != "gap_check_only":
        raise ValueError("Android Skills must remain gap_check_only")
    if lock.get("tracked_ref") != "main":
        raise ValueError("Android Skills tracked ref must be main")
    subtrees = lock.get("subtrees")
    if (
        not isinstance(subtrees, list)
        or not subtrees
        or subtrees != sorted(set(subtrees))
        or any(
            not isinstance(value, str)
            or not value.startswith("profilers/")
            or ".." in Path(value).parts
            for value in subtrees
        )
    ):
        raise ValueError("Android Skills subtrees must be safe and sorted")
    trees = lock.get("trees")
    if not isinstance(trees, dict) or list(trees) != subtrees:
        raise ValueError("Android Skills subtree trees must match tracked subtrees")
    for subtree, tree in trees.items():
        _require_hash(tree, f"Android Skills tree {subtree}", COMMIT)
    return lock


def write_generated_base_manifest(lock_path: Path) -> None:
    lock = _read(lock_path)
    root = lock_path.parent / str(lock["generated_base_root"])
    output = lock_path.parent / str(lock["generated_base_manifest"])
    manifest = {
        "schema_version": 1,
        "source_commit": lock["commit"],
        "files": build_generated_base(root),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--smart-lock",
        type=Path,
        default=Path("upstreams/smartperfetto.lock.json"),
    )
    parser.add_argument(
        "--google-lock",
        type=Path,
        default=Path("upstreams/google-perfetto.lock.json"),
    )
    parser.add_argument(
        "--android-skills-lock",
        type=Path,
        default=Path("upstreams/android-skills.lock.json"),
    )
    parser.add_argument("--write-base-manifest", action="store_true")
    args = parser.parse_args(arguments)
    if args.write_base_manifest:
        write_generated_base_manifest(args.smart_lock)
    load_and_validate_smartperfetto_lock(args.smart_lock)
    load_and_validate_google_lock(args.google_lock)
    load_and_validate_android_skills_lock(args.android_skills_lock)
    print("upstream locks, reviewed gap inputs, and committed base are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

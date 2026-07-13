#!/usr/bin/env python3
"""Dry-run or apply a pinned SmartPerfetto public Skill import."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

try:
    from tools.upstream_locks import build_generated_base, write_generated_base_manifest
except ModuleNotFoundError:  # Direct script execution.
    from upstream_locks import build_generated_base, write_generated_base_manifest


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOCK = ROOT / "upstreams/smartperfetto.lock.json"


def _git(source: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", "-C", str(source), *arguments],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _canonical_remote(value: str) -> str:
    value = value.removesuffix(".git")
    if value.startswith("git@github.com:"):
        value = "https://github.com/" + value.removeprefix("git@github.com:")
    if value.startswith("ssh://git@github.com/"):
        value = "https://github.com/" + value.removeprefix("ssh://git@github.com/")
    return value


def validate_source(source: Path, repository: str, commit: str) -> None:
    source = source.expanduser().resolve()
    remote = _canonical_remote(_git(source, "config", "--get", "remote.origin.url"))
    if remote != repository:
        raise ValueError(f"SmartPerfetto source identity mismatch: {remote}")
    head = _git(source, "rev-parse", "HEAD")
    if head != commit:
        raise ValueError(f"SmartPerfetto source commit mismatch: {head} != {commit}")
    if _git(source, "status", "--porcelain"):
        raise ValueError("SmartPerfetto source must be clean")


def compare_import(base: Path, imported: Path) -> dict[str, object]:
    before = build_generated_base(base)
    after = build_generated_base(imported)
    before_paths = set(before)
    after_paths = set(after)
    shared = before_paths & after_paths
    return {
        "added": sorted(after_paths - before_paths),
        "removed": sorted(before_paths - after_paths),
        "changed": sorted(path for path in shared if before[path] != after[path]),
        "unchanged": sum(before[path] == after[path] for path in shared),
    }


def _is_sha256(value: object) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
    )


def compare_import_contract(
    base: Path,
    imported: dict[str, Path],
    *,
    catalog_target: Path,
    migration_target: Path,
    policy_sha256: object,
) -> dict[str, object]:
    catalog = json.loads(imported["catalog"].read_text(encoding="utf-8"))
    imported_policy_sha256 = catalog.get("source", {}).get("policy_sha256")
    return {
        **compare_import(base, imported["generated"]),
        "catalog_changed": not catalog_target.is_file()
        or catalog_target.read_bytes() != imported["catalog"].read_bytes(),
        "migration_changed": not migration_target.is_file()
        or migration_target.read_bytes() != imported["migration"].read_bytes(),
        "policy_sha256_changed": not _is_sha256(policy_sha256)
        or not _is_sha256(imported_policy_sha256)
        or imported_policy_sha256 != policy_sha256,
    }


def import_is_current(drift: dict[str, object]) -> bool:
    return not any(
        drift.get(key)
        for key in (
            "added",
            "removed",
            "changed",
            "catalog_changed",
            "migration_changed",
            "policy_sha256_changed",
        )
    )


def import_to_directory(source: Path, output: Path) -> dict[str, Path]:
    skill_root = output / "skill"
    references = skill_root / "references"
    references.mkdir(parents=True)
    shutil.copyfile(
        ROOT / "skills/perfetto-performance-analysis/references/trace-processor-lock.json",
        references / "trace-processor-lock.json",
    )
    catalog = output / "smartperfetto-export.json"
    migration = output / "migration-coverage.md"
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/export_from_smartperfetto.py"),
            "--source",
            str(source),
            "--output",
            str(catalog),
            "--skill-root",
            str(skill_root),
            "--migration-output",
            str(migration),
        ],
        cwd=ROOT,
        check=True,
    )
    return {
        "generated": skill_root / "references/generated",
        "catalog": catalog,
        "migration": migration,
    }


def _replace_tree(source: Path, target: Path) -> None:
    temporary = target.with_name(f".{target.name}.next")
    if temporary.exists():
        shutil.rmtree(temporary)
    shutil.copytree(source, temporary)
    backup = target.with_name(f".{target.name}.previous")
    if backup.exists():
        shutil.rmtree(backup)
    if target.exists():
        os.replace(target, backup)
    try:
        os.replace(temporary, target)
    except BaseException:
        if backup.exists():
            os.replace(backup, target)
        raise
    if backup.exists():
        shutil.rmtree(backup)


def apply_import(
    imported: dict[str, Path],
    lock_path: Path,
    lock: dict[str, object],
    requested_commit: str,
) -> None:
    base = lock_path.parent / str(lock["generated_base_root"])
    catalog_target = ROOT / "catalog/smartperfetto-export.json"
    migration_target = ROOT / "docs/migration-coverage.md"
    manifest_target = lock_path.parent / str(lock["generated_base_manifest"])
    file_targets = (lock_path, catalog_target, migration_target, manifest_target)
    originals = {
        path: path.read_bytes() if path.is_file() else None for path in file_targets
    }
    with tempfile.TemporaryDirectory(prefix="perfetto-skills-sync-rollback-") as temporary:
        base_backup = Path(temporary) / "generated-base"
        if base.exists():
            shutil.copytree(base, base_backup)
        try:
            _replace_tree(imported["generated"], base)
            catalog = json.loads(imported["catalog"].read_text(encoding="utf-8"))
            lock["commit"] = requested_commit
            lock["policy_sha256"] = catalog["source"]["policy_sha256"]
            lock_path.write_text(
                json.dumps(lock, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
            write_generated_base_manifest(lock_path)
            shutil.copyfile(imported["catalog"], catalog_target)
            shutil.copyfile(imported["migration"], migration_target)
        except BaseException:
            if base_backup.exists():
                _replace_tree(base_backup, base)
            elif base.exists():
                shutil.rmtree(base)
            for path, payload in originals.items():
                if payload is None:
                    path.unlink(missing_ok=True)
                else:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(payload)
            raise


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--commit", help="Proposed immutable SmartPerfetto commit")
    parser.add_argument("--report-dir", type=Path, default=ROOT / "test-output/sync")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument(
        "--check",
        action="store_true",
        help="Fail when the pinned imported snapshot differs from the source checkout.",
    )
    args = parser.parse_args(arguments)

    lock = json.loads(args.lock.read_text(encoding="utf-8"))
    requested_commit = args.commit or lock["commit"]
    validate_source(args.source, lock["repository"], requested_commit)
    with tempfile.TemporaryDirectory(prefix="perfetto-skills-smart-sync-") as temporary:
        imported = import_to_directory(args.source, Path(temporary))
        base = args.lock.parent / lock["generated_base_root"]
        drift = compare_import_contract(
            base,
            imported,
            catalog_target=ROOT / "catalog/smartperfetto-export.json",
            migration_target=ROOT / "docs/migration-coverage.md",
            policy_sha256=lock.get("policy_sha256"),
        )
        report = {
            "schema_version": 1,
            "repository": lock["repository"],
            "current_commit": lock["commit"],
            "proposed_commit": requested_commit,
            "drift": drift,
            "applied": bool(args.apply),
        }
        args.report_dir.mkdir(parents=True, exist_ok=True)
        report_path = args.report_dir / "smartperfetto-sync.json"
        report_path.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        if args.apply:
            apply_import(imported, args.lock, lock, requested_commit)
    print(report_path)
    if args.check and not import_is_current(drift):
        print("SmartPerfetto imported snapshot differs from the pinned source", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

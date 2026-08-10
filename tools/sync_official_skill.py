#!/usr/bin/env python3
"""Inventory Google's official Perfetto Skill and produce a gap-only report."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from tools.upstream_locks import load_and_validate_google_lock
    from tools.upstream_skill_inventory import (
        build_gap_report,
        git_output,
        inventory_git_subtrees,
        load_reviewed_decisions,
    )
except ModuleNotFoundError:  # Direct script execution.
    from upstream_locks import load_and_validate_google_lock
    from upstream_skill_inventory import (
        build_gap_report,
        git_output,
        inventory_git_subtrees,
        load_reviewed_decisions,
    )


ROOT = Path(__file__).resolve().parents[1]
PREFIX = "ai/skills/perfetto"


def inventory_official_skill(perfetto: Path, revision: str) -> dict[str, object]:
    inventory = inventory_git_subtrees(
        perfetto,
        revision,
        repository_url="https://github.com/google/perfetto",
        subtrees=(PREFIX,),
    )
    trees = inventory.pop("trees")
    inventory["tree"] = trees[PREFIX]
    return inventory


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--perfetto", required=True, type=Path)
    parser.add_argument(
        "--lock", type=Path, default=ROOT / "upstreams/google-perfetto.lock.json"
    )
    parser.add_argument("--report-dir", type=Path, default=ROOT / "test-output/sync")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument(
        "--decisions",
        type=Path,
        default=ROOT / "upstreams/official-skill-decisions.json",
    )
    parser.add_argument(
        "--revision",
        help="Inventory a release for canary review without changing the pinned lock",
    )
    args = parser.parse_args(arguments)
    lock = load_and_validate_google_lock(
        args.lock, validate_snapshots=not args.apply
    )
    official_reference = lock["official_reference"]
    revision = args.revision or official_reference["tag"]
    peeled = str(git_output(args.perfetto, "rev-parse", f"{revision}^{{}}")).strip()
    if args.revision is None and peeled != official_reference["commit"]:
        raise ValueError(f"official Perfetto tag mismatch: {revision} -> {peeled}")
    if args.apply and args.revision is not None:
        raise ValueError("canary revision cannot be applied without updating the lock")
    current = inventory_official_skill(args.perfetto, revision)
    snapshot_path = ROOT / "upstreams/snapshots/google-perfetto/official-skill.json"
    previous = (
        json.loads(snapshot_path.read_text(encoding="utf-8"))
        if snapshot_path.is_file()
        else {"files": []}
    )
    report = build_gap_report(
        previous,
        current,
        load_reviewed_decisions(args.decisions),
    )
    args.report_dir.mkdir(parents=True, exist_ok=True)
    report_path = args.report_dir / "official-skill-gap.json"
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if args.apply:
        if report["unresolved"]:
            raise ValueError(
                "official Skill gap has unresolved review: "
                + ", ".join(report["unresolved"])
            )
        snapshot_path.parent.mkdir(parents=True, exist_ok=True)
        snapshot_path.write_text(
            json.dumps(current, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        official = lock["official_reference"]["skill"]
        official["snapshot_sha256"] = hashlib.sha256(
            snapshot_path.read_bytes()
        ).hexdigest()
        official_files = {item["path"]: item["sha256"] for item in current["files"]}
        official["sha256"] = official_files[official["path"]]
        args.lock.write_text(
            json.dumps(lock, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        committed_report = ROOT / "upstreams/reports/official-skill-gap.json"
        committed_report.parent.mkdir(parents=True, exist_ok=True)
        committed_report.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    print(report_path)
    if report["unresolved"] or (
        args.revision is not None
        and any(report[key] for key in ("added", "removed", "changed"))
    ):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

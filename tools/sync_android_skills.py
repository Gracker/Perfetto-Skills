#!/usr/bin/env python3
"""Inventory the Android Skills Perfetto profilers and produce a reviewed gap report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from tools.upstream_locks import load_and_validate_android_skills_lock
    from tools.upstream_skill_inventory import (
        build_gap_report,
        inventory_git_subtrees,
        load_reviewed_decisions,
        validate_git_source,
    )
except ModuleNotFoundError:  # Direct script execution.
    from upstream_locks import load_and_validate_android_skills_lock
    from upstream_skill_inventory import (
        build_gap_report,
        inventory_git_subtrees,
        load_reviewed_decisions,
        validate_git_source,
    )


ROOT = Path(__file__).resolve().parents[1]
ANDROID_SKILLS_REPOSITORY = "https://github.com/android/skills"
TRACKED_SUBTREES = (
    "profilers/perfetto-sql",
    "profilers/perfetto-trace-analysis",
)


def inventory_android_skills(source: Path, revision: str) -> dict[str, object]:
    return inventory_git_subtrees(
        source,
        revision,
        repository_url=ANDROID_SKILLS_REPOSITORY,
        subtrees=TRACKED_SUBTREES,
    )


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument(
        "--lock", type=Path, default=ROOT / "upstreams/android-skills.lock.json"
    )
    parser.add_argument(
        "--decisions",
        type=Path,
        default=ROOT / "upstreams/android-skills-decisions.json",
    )
    parser.add_argument("--report-dir", type=Path, default=ROOT / "test-output/sync")
    parser.add_argument("--commit", help="Proposed immutable Android Skills commit")
    parser.add_argument(
        "--revision",
        help="Inventory a canary revision without changing the pinned lock",
    )
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(arguments)
    if args.commit and args.revision:
        parser.error("--commit and --revision are mutually exclusive")
    if args.apply and args.revision:
        parser.error("--revision is a dry-run canary input")

    lock = load_and_validate_android_skills_lock(args.lock)
    pinned_commit = validate_git_source(
        args.source, lock["repository"], lock["commit"]
    )
    candidate = args.revision or args.commit or lock["commit"]
    candidate_commit = validate_git_source(
        args.source, lock["repository"], candidate
    )
    previous = inventory_android_skills(args.source, pinned_commit)
    if previous["trees"] != lock["trees"]:
        raise ValueError(
            "pinned Android Skills subtree trees differ from the reviewed lock"
        )
    current = (
        previous
        if candidate_commit == pinned_commit
        else inventory_android_skills(args.source, candidate_commit)
    )
    report = build_gap_report(
        previous,
        current,
        load_reviewed_decisions(args.decisions),
    )
    report["candidate_trees"] = current["trees"]
    report["applied"] = bool(args.apply)
    args.report_dir.mkdir(parents=True, exist_ok=True)
    report_path = args.report_dir / "android-skills-gap.json"
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    if args.apply:
        if report["unresolved"]:
            raise ValueError(
                "Android Skills gap has unresolved review: "
                + ", ".join(report["unresolved"])
            )
        lock["commit"] = candidate_commit
        lock["trees"] = current["trees"]
        args.lock.write_text(
            json.dumps(lock, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        committed_report = args.lock.parent / "reports/android-skills-gap.json"
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

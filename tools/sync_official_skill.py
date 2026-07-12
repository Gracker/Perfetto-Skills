#!/usr/bin/env python3
"""Inventory Google's official Perfetto Skill and produce a gap-only report."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

try:
    from tools.upstream_locks import load_and_validate_google_lock
except ModuleNotFoundError:  # Direct script execution.
    from upstream_locks import load_and_validate_google_lock


ROOT = Path(__file__).resolve().parents[1]
PREFIX = "ai/skills/perfetto"
OUTCOMES = {"adopted", "already_covered", "not_applicable", "pending_review"}


def _git(repository: Path, *arguments: str, text: bool = True) -> str | bytes:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=True,
        capture_output=True,
        text=text,
    ).stdout


def inventory_official_skill(perfetto: Path, revision: str) -> dict[str, object]:
    commit = str(_git(perfetto, "rev-parse", f"{revision}^{{commit}}")).strip()
    tree = str(_git(perfetto, "rev-parse", f"{revision}:{PREFIX}")).strip()
    paths = str(
        _git(perfetto, "ls-tree", "-r", "--name-only", revision, PREFIX)
    ).splitlines()
    files = []
    for path in sorted(item for item in paths if item):
        payload = _git(perfetto, "show", f"{revision}:{path}", text=False)
        assert isinstance(payload, bytes)
        files.append(
            {
                "path": path,
                "sha256": hashlib.sha256(payload).hexdigest(),
                "size": len(payload),
                "license": "Apache-2.0",
            }
        )
    return {
        "schema_version": 1,
        "repository": "https://github.com/google/perfetto",
        "revision": revision,
        "commit": commit,
        "tree": tree,
        "role": "gap_check_only",
        "files": files,
    }


def build_gap_report(
    previous: dict[str, object],
    current: dict[str, object],
    local_contract: dict[str, str],
    reviewed_decisions: dict[tuple[str, str], str] | None = None,
) -> dict[str, object]:
    reviewed_decisions = reviewed_decisions or {}
    before = {item["path"]: item["sha256"] for item in previous.get("files", [])}
    after = {item["path"]: item["sha256"] for item in current.get("files", [])}
    added = set(after) - set(before)
    changed = {
        path for path in set(before) & set(after) if before[path] != after[path]
    }
    classifications = []
    for path in sorted(after):
        outcome = "pending_review"
        if path in added or path in changed:
            outcome = reviewed_decisions.get((path, after[path]), "pending_review")
        else:
            for prefix in sorted(local_contract, key=len, reverse=True):
                if path.startswith(prefix):
                    outcome = local_contract[prefix]
                    break
        if outcome not in OUTCOMES:
            raise ValueError(f"invalid official Skill gap outcome: {outcome}")
        classifications.append({"path": path, "outcome": outcome})
    removed = sorted(set(before) - set(after))
    removed_classifications = [
        {
            "path": path,
            "sha256": before[path],
            "outcome": reviewed_decisions.get(
                (path, before[path]), "pending_review"
            ),
        }
        for path in removed
    ]
    unresolved = sorted(
        [
            item["path"]
            for item in classifications
            if item["outcome"] == "pending_review"
            and item["path"] in added | changed
        ]
        + [
            item["path"]
            for item in removed_classifications
            if item["outcome"] == "pending_review"
        ]
    )
    return {
        "schema_version": 1,
        "role": "gap_check_only",
        "previous_commit": previous.get("commit"),
        "current_commit": current.get("commit"),
        "added": sorted(added),
        "removed": removed,
        "changed": sorted(changed),
        "classifications": classifications,
        "removed_classifications": removed_classifications,
        "unresolved": unresolved,
    }


def load_reviewed_decisions(path: Path) -> dict[tuple[str, str], str]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1 or not isinstance(
        document.get("decisions"), list
    ):
        raise ValueError("invalid official Skill decision registry")
    decisions = {}
    for item in document["decisions"]:
        if (
            not isinstance(item, dict)
            or not isinstance(item.get("path"), str)
            or not isinstance(item.get("sha256"), str)
            or len(item["sha256"]) != 64
            or item.get("outcome") not in OUTCOMES - {"pending_review"}
            or not isinstance(item.get("reason"), str)
            or not item["reason"].strip()
        ):
            raise ValueError("invalid official Skill reviewed decision")
        key = (item["path"], item["sha256"])
        if key in decisions:
            raise ValueError(f"duplicate official Skill reviewed decision: {key[0]}")
        decisions[key] = item["outcome"]
    return decisions


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--perfetto", required=True, type=Path)
    parser.add_argument("--lock", type=Path, default=ROOT / "upstreams/google-perfetto.lock.json")
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
    tag = args.revision or lock["tag"]
    peeled = str(_git(args.perfetto, "rev-parse", f"{tag}^{{}}")).strip()
    if args.revision is None and peeled != lock["commit"]:
        raise ValueError(f"official Perfetto tag mismatch: {tag} -> {peeled}")
    if args.apply and args.revision is not None:
        raise ValueError("canary revision cannot be applied without updating the lock")
    current = inventory_official_skill(args.perfetto, tag)
    snapshot_path = ROOT / "upstreams/snapshots/google-perfetto/official-skill.json"
    previous = (
        json.loads(snapshot_path.read_text(encoding="utf-8"))
        if snapshot_path.is_file()
        else {"files": []}
    )
    local_contract = {
        f"{PREFIX}/environment-references/": "already_covered",
        f"{PREFIX}/infra-references/": "already_covered",
        f"{PREFIX}/workflows/android_memory/": "already_covered",
        f"{PREFIX}/workflows/gpu/compute/nvidia/": "not_applicable",
        f"{PREFIX}/workflows/gpu/": "already_covered",
        f"{PREFIX}/SKILL-template.md": "already_covered",
    }
    report = build_gap_report(
        previous,
        current,
        local_contract,
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
        official = lock["official_skill"]
        official["snapshot_sha256"] = hashlib.sha256(snapshot_path.read_bytes()).hexdigest()
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

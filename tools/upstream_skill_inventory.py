#!/usr/bin/env python3
"""Shared exact Git-subtree inventory and reviewed path/hash gap decisions."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess
from typing import NotRequired, TypedDict


OUTCOMES = {"adopted", "already_covered", "not_applicable", "pending_review"}
REVIEWED_OUTCOMES = OUTCOMES - {"pending_review"}
HEX_SHA256 = re.compile(r"[0-9a-f]{64}")
HEX_COMMIT = re.compile(r"[0-9a-f]{40}")


class ReviewedDecision(TypedDict):
    outcome: str
    reason: str
    local_path: NotRequired[str]
    test_id: NotRequired[str]
    reviewed_source_commit: NotRequired[str]


def git_output(repository: Path, *arguments: str, text: bool = True) -> str | bytes:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=True,
        capture_output=True,
        text=text,
    ).stdout


def validate_git_source(
    repository: Path, expected_repository: str, revision: str
) -> str:
    remote = str(git_output(repository, "config", "--get", "remote.origin.url")).strip()
    normalized = remote.removesuffix(".git").replace(
        "git@github.com:", "https://github.com/"
    )
    if normalized != expected_repository:
        raise ValueError(
            f"upstream repository identity mismatch: expected {expected_repository}, got {remote}"
        )
    commit = str(git_output(repository, "rev-parse", f"{revision}^{{commit}}")).strip()
    if HEX_COMMIT.fullmatch(revision) and commit != revision:
        raise ValueError(f"upstream revision does not resolve exactly: {revision}")
    return commit


def inventory_git_subtrees(
    repository: Path,
    revision: str,
    *,
    repository_url: str,
    subtrees: tuple[str, ...],
    role: str = "gap_check_only",
) -> dict[str, object]:
    if tuple(sorted(set(subtrees))) != subtrees or not subtrees:
        raise ValueError("tracked upstream subtrees must be unique and sorted")
    commit = str(git_output(repository, "rev-parse", f"{revision}^{{commit}}")).strip()
    trees = {
        subtree: str(git_output(repository, "rev-parse", f"{revision}:{subtree}")).strip()
        for subtree in subtrees
    }
    files = []
    for subtree in subtrees:
        paths = str(
            git_output(repository, "ls-tree", "-r", "--name-only", revision, subtree)
        ).splitlines()
        for path in sorted(item for item in paths if item):
            payload = git_output(repository, "show", f"{revision}:{path}", text=False)
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
        "repository": repository_url,
        "revision": revision,
        "commit": commit,
        "trees": trees,
        "role": role,
        "files": files,
    }


def build_gap_report(
    previous: dict[str, object],
    current: dict[str, object],
    reviewed_decisions: dict[tuple[str, str], ReviewedDecision] | None = None,
) -> dict[str, object]:
    reviewed_decisions = reviewed_decisions or {}
    before = {item["path"]: item["sha256"] for item in previous.get("files", [])}
    after = {item["path"]: item["sha256"] for item in current.get("files", [])}
    added = set(after) - set(before)
    changed = {
        path for path in set(before) & set(after) if before[path] != after[path]
    }

    def classify(path: str, sha256: str) -> dict[str, object]:
        classification: dict[str, object] = {
            "path": path,
            "sha256": sha256,
            "outcome": "pending_review",
        }
        decision = reviewed_decisions.get((path, sha256))
        if decision is not None:
            classification.update(decision)
        if classification["outcome"] not in OUTCOMES:
            raise ValueError(
                f"invalid upstream Skill gap outcome: {classification['outcome']}"
            )
        return classification

    classifications = [classify(path, after[path]) for path in sorted(after)]
    removed = sorted(set(before) - set(after))
    removed_classifications = [classify(path, before[path]) for path in removed]
    unresolved = sorted(
        item["path"]
        for item in classifications + removed_classifications
        if item["outcome"] == "pending_review"
    )
    return {
        "schema_version": 1,
        "role": current.get("role", "gap_check_only"),
        "previous_commit": previous.get("commit"),
        "current_commit": current.get("commit"),
        "added": sorted(added),
        "removed": removed,
        "changed": sorted(changed),
        "classifications": classifications,
        "removed_classifications": removed_classifications,
        "unresolved": unresolved,
    }


def load_reviewed_decisions(
    path: Path,
) -> dict[tuple[str, str], ReviewedDecision]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1 or not isinstance(
        document.get("decisions"), list
    ):
        raise ValueError("invalid upstream Skill decision registry")
    decisions: dict[tuple[str, str], ReviewedDecision] = {}
    for item in document["decisions"]:
        common_keys = {"path", "sha256", "outcome", "reason"}
        evidence_keys = {"local_path", "test_id", "reviewed_source_commit"}
        outcome = item.get("outcome") if isinstance(item, dict) else None
        expected_keys = (
            common_keys | evidence_keys
            if outcome in {"adopted", "already_covered"}
            else common_keys
        )
        if (
            not isinstance(item, dict)
            or set(item) != expected_keys
            or not isinstance(item.get("path"), str)
            or not item["path"].strip()
            or not isinstance(item.get("sha256"), str)
            or HEX_SHA256.fullmatch(item["sha256"]) is None
            or outcome not in REVIEWED_OUTCOMES
            or not isinstance(item.get("reason"), str)
            or not item["reason"].strip()
            or (
                outcome in {"adopted", "already_covered"}
                and (
                    not isinstance(item.get("local_path"), str)
                    or not item["local_path"].strip()
                    or not isinstance(item.get("test_id"), str)
                    or not item["test_id"].strip()
                    or not isinstance(item.get("reviewed_source_commit"), str)
                    or HEX_COMMIT.fullmatch(item["reviewed_source_commit"]) is None
                )
            )
        ):
            raise ValueError("invalid upstream Skill reviewed decision")
        key = (item["path"], item["sha256"])
        if key in decisions:
            raise ValueError(f"duplicate upstream Skill reviewed decision: {key[0]}")
        decisions[key] = {
            key: value
            for key, value in item.items()
            if key not in {"path", "sha256"}
        }
    return decisions

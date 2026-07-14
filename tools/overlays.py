#!/usr/bin/env python3
"""Load fail-closed local Skill, Strategy, and SQL overlay descriptors."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path, PurePosixPath
import re


SHA256 = re.compile(r"^[0-9a-f]{64}$")
KINDS = {"sql", "skill", "strategy"}
UPSTREAM_STATES = {"propose", "local_only", "accepted_upstream"}


@dataclass(frozen=True)
class Overlay:
    descriptor: Path
    target: str
    kind: str
    expected_base_sha256: str
    replacement: Path
    replacement_sha256: str
    reason: str
    regression_ids: tuple[str, ...]
    base_failure_signature: str | None
    upstream_candidate: str
    dependent_replacements: tuple[tuple[str, Path, str, str], ...]


def _hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _safe_target(value: object) -> bool:
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


def load_overlays(root: Path) -> list[Overlay]:
    if not root.is_dir():
        return []
    overlays: list[Overlay] = []
    targets: set[str] = set()
    for descriptor in sorted(root.rglob("*.overlay.json")):
        data = json.loads(descriptor.read_text(encoding="utf-8"))
        target = data.get("target")
        if not _safe_target(target):
            raise ValueError(f"unsafe target in {descriptor}: {target}")
        if target in targets:
            raise ValueError(f"duplicate overlay target: {target}")
        targets.add(target)
        kind = data.get("kind")
        if kind not in KINDS:
            raise ValueError(f"unknown overlay kind in {descriptor}: {kind}")
        for field in ("expected_base_sha256", "replacement_sha256"):
            if not isinstance(data.get(field), str) or not SHA256.fullmatch(data[field]):
                raise ValueError(f"invalid {field} in {descriptor}")
        replacement_value = data.get("replacement")
        if not _safe_target(replacement_value):
            raise ValueError(f"missing replacement in {descriptor}")
        replacement = (descriptor.parent / replacement_value).resolve()
        unresolved_replacement = descriptor.parent / replacement_value
        if (
            not replacement.is_relative_to(root.resolve())
            or _uses_symlink(unresolved_replacement, root)
            or not replacement.is_file()
        ):
            raise ValueError(f"missing replacement in {descriptor}: {replacement_value}")
        if _hash(replacement) != data["replacement_sha256"]:
            raise ValueError(f"replacement hash mismatch in {descriptor}")
        reason = data.get("reason")
        if not isinstance(reason, str) or not reason.strip():
            raise ValueError(f"missing overlay reason in {descriptor}")
        regression_ids = data.get("regression_ids")
        if not isinstance(regression_ids, list) or any(
            not isinstance(item, str) or not item for item in regression_ids
        ):
            raise ValueError(f"invalid regression_ids in {descriptor}")
        base_failure = data.get("base_failure_signature")
        if kind == "sql" and (
            not regression_ids
            or not isinstance(base_failure, str)
            or not base_failure
        ):
            raise ValueError(
                f"SQL overlay requires regression_ids and base_failure_signature: {descriptor}"
            )
        upstream_candidate = data.get("upstream_candidate")
        if upstream_candidate not in UPSTREAM_STATES:
            raise ValueError(f"invalid upstream_candidate in {descriptor}")
        dependent_replacements = []
        dependent_values = data.get("dependent_replacements", [])
        if not isinstance(dependent_values, list):
            raise ValueError(f"dependent_replacements must be a list in {descriptor}")
        for dependent in dependent_values:
            if not isinstance(dependent, dict) or not _safe_target(dependent.get("target")):
                raise ValueError(f"unsafe dependent target in {descriptor}")
            dependent_path_value = dependent.get("replacement")
            dependent_hash = dependent.get("replacement_sha256")
            dependent_base_hash = dependent.get("expected_base_sha256")
            if (
                not isinstance(dependent_path_value, str)
                or not _safe_target(dependent_path_value)
                or not isinstance(dependent_hash, str)
                or not SHA256.fullmatch(dependent_hash)
                or not isinstance(dependent_base_hash, str)
                or not SHA256.fullmatch(dependent_base_hash)
            ):
                raise ValueError(f"invalid dependent replacement in {descriptor}")
            dependent_path = (descriptor.parent / dependent_path_value).resolve()
            unresolved_dependent = descriptor.parent / dependent_path_value
            if (
                not dependent_path.is_relative_to(root.resolve())
                or _uses_symlink(unresolved_dependent, root)
                or not dependent_path.is_file()
                or _hash(dependent_path) != dependent_hash
            ):
                raise ValueError(f"dependent replacement hash mismatch in {descriptor}")
            dependent_replacements.append(
                (
                    dependent["target"],
                    dependent_path,
                    dependent_hash,
                    dependent_base_hash,
                )
            )
        if kind in {"skill", "strategy"} and not dependent_replacements:
            raise ValueError(
                f"{kind} overlay requires explicit dependent_replacements: {descriptor}"
            )
        overlays.append(
            Overlay(
                descriptor=descriptor,
                target=target,
                kind=kind,
                expected_base_sha256=data["expected_base_sha256"],
                replacement=replacement,
                replacement_sha256=data["replacement_sha256"],
                reason=reason.strip(),
                regression_ids=tuple(regression_ids),
                base_failure_signature=base_failure,
                upstream_candidate=upstream_candidate,
                dependent_replacements=tuple(dependent_replacements),
            )
        )
    return overlays

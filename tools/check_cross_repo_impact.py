#!/usr/bin/env python3
"""Classify changes that may need a paired SmartPerfetto/Perfetto-Skills update."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path, PurePosixPath
from typing import Callable


PUBLIC_TRIGGERS = (
    "catalog/",
    "skills/perfetto-performance-analysis/",
    "src/",
    "upstreams/",
    "fixtures/",
    "tools/export_from_smartperfetto.py",
    "tools/compile_skill.py",
)

SMARTPERFETTO_TRIGGERS = (
    "backend/skills/",
    "backend/strategies/",
    "backend/src/services/skillEngine/",
    "backend/src/services/skillPacks/",
    "backend/src/services/evidence/",
    "backend/src/services/claimVerification/",
    "backend/src/services/identity/",
    "backend/src/services/processIdentity/",
    "backend/src/services/verifier/",
    "backend/src/services/perfetto",
    "backend/src/services/smartperfettoSqlPackage.ts",
    "backend/src/services/renderingPipelineDetectionSkillGenerator.ts",
    "backend/src/services/stdlibSkillCoverage.ts",
    "backend/src/services/finalReportContractGate",
    "backend/src/services/report",
    "backend/src/services/comparison",
    "backend/src/services/analysisResultSnapshot",
    "backend/src/services/multiTraceComparison",
    "backend/src/agent/decision/",
    "backend/src/agent/core/executors/directSkillExecutor.ts",
    "backend/src/agent/core/executors/comparisonExecutor.ts",
    "backend/src/types/claimVerification.ts",
    "backend/src/types/evidenceContract.ts",
    "backend/src/types/identityContract.ts",
    "backend/src/types/perfettoSql.ts",
    "backend/src/types/multiTraceComparison.ts",
    "backend/src/data/perfettoSchema.ts",
    "backend/data/perfettoStdlibSymbols.json",
    "backend/data/perfettoSqlDocs.json",
    "perfetto",
    "docs/rendering_pipelines/",
    "backend/skills/public-export.yaml",
    "scripts/trace-processor-pin.env",
    "scripts/verify-public-skill-export.sh",
    ".claude/rules/skills.md",
    ".claude/rules/perfetto-sync.md",
)

REPOSITORIES = {
    "perfetto-skills": ("SmartPerfetto", PUBLIC_TRIGGERS),
    "smartperfetto": ("Perfetto-Skills", SMARTPERFETTO_TRIGGERS),
}
DECISIONS = ("required", "not_required", "deferred")


def _matches(path: str, trigger: str) -> bool:
    return path.startswith(trigger)


def _normalize_path(path: str) -> str:
    normalized = path[2:] if path.startswith("./") else path
    pure = PurePosixPath(normalized)
    if pure.is_absolute() or ".." in pure.parts:
        raise ValueError(f"unsafe changed path: {path}")
    return pure.as_posix()


def classify(repository: str, paths: Sequence[str]) -> dict[str, object]:
    """Return deterministic path-only impact classification."""
    try:
        paired_repository, triggers = REPOSITORIES[repository]
    except KeyError as error:
        raise ValueError(f"unsupported repository: {repository}") from error

    normalized_paths = sorted({_normalize_path(path) for path in paths if path.strip()})
    matched_paths = [
        path for path in normalized_paths if any(_matches(path, trigger) for trigger in triggers)
    ]
    return {
        "repository": repository,
        "paired_repository": paired_repository,
        "review_required": bool(matched_paths),
        "matched_paths": matched_paths,
        "change_fingerprint": hashlib.sha256(
            (repository + "\0" + "\0".join(normalized_paths)).encode("utf-8")
        ).hexdigest(),
        "decision": None,
    }


def evaluate(
    repository: str,
    paths: Sequence[str],
    *,
    decision: str | None = None,
    reason: str | None = None,
    handoff: str | None = None,
    paired_path: Path | None = None,
    paired_ref: str | None = None,
) -> dict[str, object]:
    """Attach and validate the maintainer's semantic impact decision."""
    result = classify(repository, paths)
    review_required = bool(result["review_required"])

    if not review_required and decision is None:
        decision = "not_required"
        reason = "no paired-contract paths changed"
    elif review_required and decision is None:
        raise ValueError("triggered changes require an explicit --decision")

    if decision not in DECISIONS:
        raise ValueError(f"decision must be one of: {', '.join(DECISIONS)}")
    if not reason or not reason.strip():
        raise ValueError(f"{decision} requires a non-empty --reason")
    if decision == "deferred" and (not handoff or not handoff.strip()):
        raise ValueError("deferred requires a durable --handoff")
    paired_evidence = None
    if decision == "required":
        if paired_path is None:
            raise ValueError("required requires --paired-path for paired repository validation")
        if paired_ref is None:
            raise ValueError("required requires an immutable --paired-ref")
        paired_evidence = _validate_paired_repository(
            repository, paired_path, paired_ref=paired_ref
        )

    result.update(
        {
            "decision": decision,
            "reason": reason.strip(),
            "handoff": handoff.strip() if handoff else None,
            "paired_evidence": paired_evidence,
        }
    )
    return result


def _run_git(command: list[str]) -> str:
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout


def collect_changed_paths(
    base: str | None,
    *,
    runner: Callable[[list[str]], str] = _run_git,
) -> list[str]:
    if base is None:
        base = runner(["git", "merge-base", "HEAD", "origin/main"]).strip()
    commands = (
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        ["git", "diff", "--cached", "--name-only"],
        ["git", "diff", "--name-only"],
        ["git", "ls-files", "--others", "--exclude-standard"],
    )
    return sorted(
        {
            line
            for command in commands
            for line in runner(command).splitlines()
            if line
        }
    )


def _validate_paired_repository(
    repository: str, paired_path: Path, *, paired_ref: str | None
) -> dict[str, str]:
    path = paired_path.expanduser().resolve()
    if not path.is_dir():
        raise ValueError(f"paired repository does not exist: {path}")
    expected_slug = (
        "Gracker/SmartPerfetto"
        if repository == "perfetto-skills"
        else "Gracker/Perfetto-Skills"
    )
    remote = _run_git(
        ["git", "-C", str(path), "config", "--get", "remote.origin.url"]
    ).strip()
    normalized_remote = remote.removesuffix(".git").replace(
        "git@github.com:", "https://github.com/"
    )
    if not normalized_remote.endswith(expected_slug):
        raise ValueError(
            f"paired repository identity mismatch: expected {expected_slug}, got {remote}"
        )
    head = _run_git(["git", "-C", str(path), "rev-parse", "HEAD"]).strip()
    if paired_ref is not None:
        if len(paired_ref) != 40 or any(
            character not in "0123456789abcdef" for character in paired_ref
        ):
            raise ValueError("--paired-ref must be a lowercase 40-character commit")
        try:
            _run_git(
                ["git", "-C", str(path), "cat-file", "-e", f"{paired_ref}^{{commit}}"]
            )
        except subprocess.CalledProcessError as error:
            raise ValueError(f"paired ref does not exist: {paired_ref}") from error
        resolved = _run_git(
            ["git", "-C", str(path), "rev-parse", f"{paired_ref}^{{commit}}"]
        ).strip()
        if resolved != paired_ref:
            raise ValueError(f"paired ref does not resolve exactly: {paired_ref}")
        if head != paired_ref:
            raise ValueError(f"paired ref must equal paired checkout HEAD: {paired_ref} != {head}")
    return {"repository": remote, "head": head, "validated_ref": paired_ref or head}


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True, choices=sorted(REPOSITORIES))
    parser.add_argument("--base")
    parser.add_argument("--path", action="append", default=[])
    parser.add_argument("--decision", choices=DECISIONS)
    parser.add_argument("--reason")
    parser.add_argument("--handoff")
    parser.add_argument("--paired-path", type=Path)
    parser.add_argument("--paired-ref")
    return parser


def main(arguments: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(arguments)
    try:
        paths = args.path or collect_changed_paths(args.base)
        result = evaluate(
            args.repository,
            paths,
            decision=args.decision,
            reason=args.reason,
            handoff=args.handoff,
            paired_path=args.paired_path,
            paired_ref=args.paired_ref,
        )
    except (subprocess.CalledProcessError, ValueError) as error:
        print(f"cross-repository impact check failed: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

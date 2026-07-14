#!/usr/bin/env python3
"""Scan trace bytes for high-risk printable strings without echoing secrets."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

try:
    from tools.fixture_manifest import sha256_file
except ModuleNotFoundError:  # Direct script execution.
    from fixture_manifest import sha256_file


RULESET_VERSION = "fixture-privacy-v2"
RULES = (
    (
        "email",
        re.compile(
            rb"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\."
            rb"(?:com|org|net|edu|gov|mil|io|dev|app|co|cn|de|fr|jp|uk)\b",
            re.IGNORECASE,
        ),
    ),
    ("bearer_token", re.compile(rb"(?i)bearer[ \t]+[A-Za-z0-9._~+/=-]{8,}")),
    (
        "api_key",
        re.compile(
            rb"(?:sk-[A-Za-z0-9]{20,}|rk-live-[A-Za-z0-9]{20,}|"
            rb"ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})"
        ),
    ),
    ("private_home_path", re.compile(rb"/(?:Users|home)/[^/\x00\s]+/")),
    (
        "account_identifier",
        re.compile(
            rb"(?i)(?:account(?:_?name|_?id)?|user_?email)[=:][ \t]*"
            rb"[A-Za-z0-9._@+-]{3,128}"
        ),
    ),
)
IDENTIFIER = re.compile(
    rb"\b(?:[A-Za-z][A-Za-z0-9_]*\.){2,}[A-Za-z][A-Za-z0-9_:$-]*\b"
)


def scan_file(
    path: Path,
    *,
    identifier_reviewer: str | None = None,
    reviewed_at: str | None = None,
) -> dict[str, object]:
    payload = path.read_bytes()
    findings: list[dict[str, object]] = []
    for rule, pattern in RULES:
        for match in pattern.finditer(payload):
            value = match.group(0)
            findings.append(
                {
                    "rule": rule,
                    "offset": match.start(),
                    "length": len(value),
                    "value_sha256": hashlib.sha256(value).hexdigest(),
                }
            )
    findings.sort(key=lambda item: (int(item["offset"]), str(item["rule"])))
    identifier_hashes = sorted(
        {hashlib.sha256(match.group(0)).hexdigest() for match in IDENTIFIER.finditer(payload)}
    )
    identifier_inventory_sha256 = hashlib.sha256(
        "\n".join(identifier_hashes).encode("ascii")
    ).hexdigest()
    return {
        "path": path.name,
        "sha256": sha256_file(path),
        "ruleset": RULESET_VERSION,
        "passed": not findings,
        "findings": findings,
        "identifier_review": {
            "status": "approved" if identifier_reviewer and reviewed_at else "pending",
            "reviewer": identifier_reviewer,
            "reviewed_at": reviewed_at,
            "inventory_count": len(identifier_hashes),
            "inventory_sha256": identifier_inventory_sha256,
        },
    }


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--approve-identifiers", metavar="REVIEWER")
    parser.add_argument("--reviewed-at", metavar="YYYY-MM-DD")
    args = parser.parse_args(arguments)
    if bool(args.approve_identifiers) != bool(args.reviewed_at):
        parser.error("--approve-identifiers and --reviewed-at must be provided together")
    results = [
        scan_file(
            path,
            identifier_reviewer=args.approve_identifiers,
            reviewed_at=args.reviewed_at,
        )
        for path in args.trace
    ]
    report = {"ruleset": RULESET_VERSION, "results": results}
    output = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    return 0 if all(
        bool(result["passed"])
        and result["identifier_review"]["status"] == "approved"
        for result in results
    ) else 1


if __name__ == "__main__":
    raise SystemExit(main())

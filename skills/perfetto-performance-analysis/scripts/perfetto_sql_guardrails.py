#!/usr/bin/env python3
"""Review authored PerfettoSQL for portable safety invariants and advisories."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from collections.abc import Sequence

from runtime.sql_guardrails import GuardrailIssue, analyze_sql


def _render_text(path: str, issues: Sequence[GuardrailIssue]) -> str:
    if not issues:
        return f"{path}: OK"
    return "\n".join(
        f"{path}:{issue.line}: {issue.severity} {issue.rule_id}: "
        f"{issue.message} [{issue.snippet}]"
        for issue in issues
    )


def main(arguments: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sql_files", nargs="*", type=Path)
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Return non-zero for advisories as well as errors.",
    )
    args = parser.parse_args(arguments)

    sources = (
        [(str(path), path.read_text(encoding="utf-8")) for path in args.sql_files]
        if args.sql_files
        else [("<stdin>", sys.stdin.read())]
    )
    analyzed = [(path, analyze_sql(sql)) for path, sql in sources]
    errors = sum(
        issue.severity == "error" for _, issues in analyzed for issue in issues
    )
    advisories = sum(
        issue.severity == "advisory" for _, issues in analyzed for issue in issues
    )
    if args.format == "json":
        print(
            json.dumps(
                {
                    "files": [
                        {
                            "path": path,
                            "issues": [issue.to_dict() for issue in issues],
                        }
                        for path, issues in analyzed
                    ],
                    "summary": {
                        "files": len(analyzed),
                        "errors": errors,
                        "advisories": advisories,
                    },
                },
                indent=2,
                sort_keys=True,
            )
        )
    else:
        print("\n".join(_render_text(path, issues) for path, issues in analyzed))
    return int(errors > 0 or (args.strict and advisories > 0))


if __name__ == "__main__":
    raise SystemExit(main())

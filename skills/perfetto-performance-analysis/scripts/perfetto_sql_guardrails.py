#!/usr/bin/env python3
"""Review authored PerfettoSQL for portable safety invariants and advisories."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import sys
from collections.abc import Sequence


PROOF_TOKEN = "perfetto-span-join-non-overlap-proof"
SPAN_JOIN = re.compile(r"\bSPAN(?:_LEFT)?_JOIN\b", re.IGNORECASE)
CREATE_SPAN_JOIN = re.compile(
    r"\bCREATE\s+VIRTUAL\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"
    r"([A-Za-z_][\w.]*)\s+USING\s+SPAN(?:_LEFT)?_JOIN\b[\s\S]*?(?:;|$)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class GuardrailIssue:
    rule_id: str
    severity: str
    message: str
    line: int
    snippet: str

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def _mask_comments_and_strings(sql: str) -> str:
    output: list[str] = []
    index = 0
    while index < len(sql):
        current = sql[index]
        following = sql[index + 1] if index + 1 < len(sql) else ""
        if current == "-" and following == "-":
            while index < len(sql) and sql[index] != "\n":
                output.append(" ")
                index += 1
            continue
        if current == "/" and following == "*":
            output.extend((" ", " "))
            index += 2
            while index < len(sql) and not (
                sql[index] == "*" and index + 1 < len(sql) and sql[index + 1] == "/"
            ):
                output.append("\n" if sql[index] == "\n" else " ")
                index += 1
            if index < len(sql):
                output.extend((" ", " "))
                index += 2
            continue
        if current == "'":
            output.append(" ")
            index += 1
            while index < len(sql):
                if sql[index] == "'":
                    if index + 1 < len(sql) and sql[index + 1] == "'":
                        output.extend((" ", " "))
                        index += 2
                        continue
                    output.append(" ")
                    index += 1
                    break
                output.append("\n" if sql[index] == "\n" else " ")
                index += 1
            continue
        output.append(current)
        index += 1
    return "".join(output)


def _line_start(sql: str, index: int) -> int:
    previous = sql.rfind("\n", 0, max(0, index))
    return 0 if previous == -1 else previous + 1


def _line_number(sql: str, index: int) -> int:
    return sql.count("\n", 0, max(0, index)) + 1


def _snippet(sql: str, index: int) -> str:
    start = _line_start(sql, index)
    end = sql.find("\n", start)
    value = sql[start : len(sql) if end == -1 else end].strip()
    return value if len(value) <= 160 else value[:157] + "..."


def _issue(
    sql: str,
    index: int,
    rule_id: str,
    severity: str,
    message: str,
) -> GuardrailIssue:
    return GuardrailIssue(
        rule_id=rule_id,
        severity=severity,
        message=message,
        line=_line_number(sql, index),
        snippet=_snippet(sql, index),
    )


def _has_adjacent_proof(sql: str, create_index: int) -> bool:
    create_line_start = _line_start(sql, create_index)
    if create_line_start == 0:
        return False
    previous_end = create_line_start - 1
    previous_start = _line_start(sql, previous_end)
    previous_line = sql[previous_start:previous_end].strip()
    return (
        re.fullmatch(
            rf"--\s*{re.escape(PROOF_TOKEN)}\s*:\s*\S(?:.*\S)?\s*",
            previous_line,
            re.IGNORECASE,
        )
        is not None
    )


def _has_preceding_drop(
    masked_sql: str, create_index: int, table_name: str
) -> bool:
    return (
        re.search(
            rf"\bDROP\s+TABLE\s+IF\s+EXISTS\s+{re.escape(table_name)}\b",
            masked_sql[:create_index],
            re.IGNORECASE,
        )
        is not None
    )


def _add_regex_issues(
    issues: list[GuardrailIssue],
    sql: str,
    masked_sql: str,
    pattern: str,
    rule_id: str,
    message: str,
) -> None:
    for match in re.finditer(pattern, masked_sql, re.IGNORECASE):
        issues.append(_issue(sql, match.start(), rule_id, "advisory", message))


def analyze_sql(sql: str) -> list[GuardrailIssue]:
    """Return deterministic error/advisory findings without executing SQL."""
    masked_sql = _mask_comments_and_strings(sql)
    issues: list[GuardrailIssue] = []
    create_matches = list(CREATE_SPAN_JOIN.finditer(masked_sql))
    for match in create_matches:
        statement = match.group(0)
        create_index = match.start()
        join_match = SPAN_JOIN.search(statement)
        issue_index = create_index + (join_match.start() if join_match else 0)
        partition_keys = [
            key.lower()
            for key in re.findall(
                r"\bPARTITIONED\s+([A-Za-z_][A-Za-z0-9_]*)",
                statement,
                re.IGNORECASE,
            )
        ]
        if len(partition_keys) > 1 and len(set(partition_keys)) > 1:
            issues.append(
                _issue(
                    sql,
                    issue_index,
                    "span-join-safety",
                    "error",
                    "When both SPAN_JOIN inputs are PARTITIONED, they must use the same partition key.",
                )
            )
        if not _has_preceding_drop(masked_sql, create_index, match.group(1)):
            issues.append(
                _issue(
                    sql,
                    create_index,
                    "span-join-idempotency",
                    "error",
                    "Reusable SPAN_JOIN virtual tables require a preceding DROP TABLE IF EXISTS.",
                )
            )
        if not _has_adjacent_proof(sql, create_index):
            issues.append(
                _issue(
                    sql,
                    issue_index,
                    "span-join-non-overlap",
                    "error",
                    "PARTITIONED scopes entity matching but does not make overlapping intervals within an input partition safe. Reference a fixture/assertion or witness query in an adjacent perfetto-span-join-non-overlap-proof comment.",
                )
            )
    if SPAN_JOIN.search(masked_sql) and not create_matches:
        match = SPAN_JOIN.search(masked_sql)
        assert match is not None
        issues.append(
            _issue(
                sql,
                match.start(),
                "span-join-safety",
                "error",
                "SPAN_JOIN usage could not be associated with a reviewable CREATE VIRTUAL TABLE statement.",
            )
        )

    _add_regex_issues(
        issues,
        sql,
        masked_sql,
        r"\b(?:NOT\s+)?LIKE\b",
        "prefer-glob-for-like",
        "Prefer GLOB for wildcard matching or = for exact text matching.",
    )
    _add_regex_issues(
        issues,
        sql,
        masked_sql,
        r"\b(?:SUM|AVG|MIN|MAX)\s*\([^)]*\b(?:\w+\.)?dur\b|\b(?:\w+\.)?ts\s*\+\s*(?:\w+\.)?dur\b",
        "safe-duration-boundary",
        "Review raw dur arithmetic for dur = -1 and use an effective duration when the source can contain open intervals.",
    )
    _add_regex_issues(
        issues,
        sql,
        masked_sql,
        r"\b(?:\w+\.)?ts\s*(?:>=|>|BETWEEN)\s*(?:\$\{start_ts[^}]*\}|(?:\w+\.)?start_ts\b)",
        "overlap-range-filter",
        "Interval queries should use an overlap predicate instead of a start-only boundary.",
    )
    _add_regex_issues(
        issues,
        sql,
        masked_sql,
        r"\bCREATE\s+(?!OR\s+REPLACE\b)(?!TEMP(?:ORARY)?\b)(?!VIRTUAL\b)"
        r"(?:PERFETTO\s+)?(?:FUNCTION|MACRO|TABLE|VIEW)\s+(?!IF\s+NOT\s+EXISTS\b)",
        "idempotent-create",
        "Reusable objects should use CREATE OR REPLACE, IF NOT EXISTS, or a reviewed preceding drop.",
    )
    _add_regex_issues(
        issues,
        sql,
        masked_sql,
        r"\b(?:FROM|JOIN)\s+args\b",
        "safe-arg-extraction",
        "Prefer EXTRACT_ARG over direct args table parsing.",
    )
    return sorted(issues, key=lambda issue: (issue.line, issue.rule_id, issue.message))


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

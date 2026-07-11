#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from _common import parse_csv_output, run_query, write_text_atomic


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run one Perfetto SQL result set with trace_processor_shell."
    )
    parser.add_argument("trace", type=Path)
    query = parser.add_mutually_exclusive_group(required=True)
    query.add_argument("--sql", help="Inline Perfetto SQL.")
    query.add_argument("--sql-file", type=Path, help="UTF-8 SQL file.")
    parser.add_argument("--trace-processor")
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--format", choices=("json", "csv", "raw"), default="json")
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = run_query(
            args.trace,
            sql=args.sql,
            sql_file=args.sql_file,
            trace_processor=args.trace_processor,
            timeout=args.timeout,
        )
        if args.format == "json":
            rendered = json.dumps(
                parse_csv_output(result.stdout),
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n"
        else:
            rendered = result.stdout
        if args.output:
            write_text_atomic(args.output, rendered)
        else:
            sys.stdout.write(rendered)
        if result.stderr:
            sys.stderr.write(result.stderr)
        return 0
    except (FileNotFoundError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())


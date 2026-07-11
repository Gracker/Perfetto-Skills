#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

from _common import (
    DEFAULT_MAX_OUTPUT_BYTES,
    parse_csv_output,
    render_sql_template,
    run_query,
    write_text_atomic,
)


MODULE_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_.]*$")


def split_assignment(value: str, label: str) -> tuple[str, str]:
    name, separator, raw = value.partition("=")
    if not separator or not name:
        raise ValueError(f"{label} must use NAME=VALUE")
    return name, raw


def parse_parameters(values: list[str]) -> dict[str, object]:
    parameters: dict[str, object] = {}
    for item in values:
        name, raw = split_assignment(item, "--param")
        if name in parameters:
            raise ValueError(f"duplicate --param: {name}")
        try:
            parameters[name] = json.loads(raw)
        except json.JSONDecodeError:
            parameters[name] = raw
    return parameters


def load_results(values: list[str]) -> dict[str, object]:
    results: dict[str, object] = {}
    for item in values:
        name, raw_path = split_assignment(item, "--result")
        if name in results:
            raise ValueError(f"duplicate --result: {name}")
        path = Path(raw_path).expanduser().resolve()
        results[name] = json.loads(path.read_text(encoding="utf-8"))
    return results


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
    parser.add_argument(
        "--max-output-bytes",
        type=int,
        default=DEFAULT_MAX_OUTPUT_BYTES,
        help="Maximum stdout and stderr bytes accepted from trace_processor_shell.",
    )
    parser.add_argument(
        "--param",
        action="append",
        default=[],
        metavar="NAME=JSON",
        help=(
            "Bind ${NAME} using a JSON scalar, a JSON array for an SQL literal "
            "list, or a raw string."
        ),
    )
    parser.add_argument(
        "--result",
        action="append",
        default=[],
        metavar="NAME=PATH",
        help=(
            "Bind ${NAME} to a non-empty JSON row array; dotted fields and "
            "numeric indexes select scalar values."
        ),
    )
    parser.add_argument(
        "--module",
        action="append",
        default=[],
        help="Prepend a validated INCLUDE PERFETTO MODULE statement.",
    )
    parser.add_argument("--format", choices=("json", "csv", "raw"), default="json")
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if any(not MODULE_PATTERN.fullmatch(module) for module in args.module):
            raise ValueError("--module names may contain only letters, digits, dots, and underscores")
        template = (
            args.sql_file.read_text(encoding="utf-8")
            if args.sql_file is not None
            else args.sql
        )
        assert template is not None
        sql = render_sql_template(
            template,
            parse_parameters(args.param),
            load_results(args.result),
        )
        if args.module:
            includes = "\n".join(
                f"INCLUDE PERFETTO MODULE {module};" for module in args.module
            )
            sql = includes + "\n" + sql
        result = run_query(
            args.trace,
            sql=sql,
            trace_processor=args.trace_processor,
            timeout=args.timeout,
            max_output_bytes=args.max_output_bytes,
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
    except (OSError, json.JSONDecodeError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

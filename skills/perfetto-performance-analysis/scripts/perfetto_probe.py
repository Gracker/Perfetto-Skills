#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from _common import (
    parse_csv_output,
    parse_scalar,
    run_query,
    sha256_file,
    write_text_atomic,
)


PROBE_SQL = """
SELECT 'trace_bounds' AS section, 'start_ns' AS key,
       CAST(start_ts AS TEXT) AS value, 'plain' AS encoding
FROM trace_bounds
UNION ALL
SELECT 'trace_bounds', 'end_ns', CAST(end_ts AS TEXT), 'plain'
FROM trace_bounds
UNION ALL
SELECT 'metadata', name,
       'hex:' || hex(CAST(COALESCE(str_value, CAST(int_value AS TEXT)) AS BLOB)),
       'hex'
FROM metadata
WHERE str_value IS NOT NULL OR int_value IS NOT NULL
UNION ALL
SELECT 'table', name, type, 'plain'
FROM sqlite_master
WHERE type IN ('table', 'view')
ORDER BY section, key;
""".strip()


CAPABILITY_TABLES = {
    "slices": {"slice"},
    "thread_states": {"thread_state"},
    "scheduling": {"sched"},
    "counters": {"counter", "counter_track"},
    "frame_timeline": {
        "actual_frame_timeline_slice",
        "expected_frame_timeline_slice",
    },
    "gpu": {"gpu_slice", "gpu_track"},
    "heap_graph": {"heap_graph_object"},
    "arguments": {"args"},
}


def build_probe(
    trace: Path,
    rows: list[dict[str, str | int | float | None]],
) -> dict[str, object]:
    bounds: dict[str, int] = {}
    metadata: dict[str, str | int | float | None] = {}
    tables: set[str] = set()
    errors: list[str] = []

    for row in rows:
        section = row.get("section")
        key = row.get("key")
        value = row.get("value")
        encoding = row.get("encoding")
        if not isinstance(key, str):
            errors.append(f"probe row has non-string key: {row}")
            continue
        if encoding == "hex":
            if not isinstance(value, str) or not value.startswith("hex:"):
                errors.append(f"probe row has non-string hex value: {row}")
                continue
            try:
                value = parse_scalar(bytes.fromhex(value.removeprefix("hex:")).decode("utf-8"))
            except (ValueError, UnicodeDecodeError) as exc:
                errors.append(f"probe row has invalid UTF-8 hex value for {key}: {exc}")
                continue
        if section == "trace_bounds" and isinstance(value, int):
            bounds[key] = value
        elif section == "metadata":
            metadata[key] = value
        elif section == "table":
            tables.add(key)

    capabilities = {
        name: required.issubset(tables)
        for name, required in CAPABILITY_TABLES.items()
    }
    resolved_trace = trace.expanduser().resolve()
    return {
        "schema_version": 1,
        "trace": {
            "path": str(resolved_trace),
            "sha256": sha256_file(resolved_trace),
            "start_ns": bounds.get("start_ns"),
            "end_ns": bounds.get("end_ns"),
        },
        "metadata": metadata,
        "tables": sorted(tables),
        "capabilities": capabilities,
        "available": sorted(name for name, available in capabilities.items() if available),
        "missing": sorted(name for name, available in capabilities.items() if not available),
        "errors": errors,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Probe trace identity, bounds, tables, metadata, and capabilities."
    )
    parser.add_argument("trace", type=Path)
    parser.add_argument("--trace-processor")
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = run_query(
            args.trace,
            sql=PROBE_SQL,
            trace_processor=args.trace_processor,
            timeout=args.timeout,
        )
        probe = build_probe(args.trace, parse_csv_output(result.stdout))
        rendered = json.dumps(
            probe, ensure_ascii=False, indent=2, sort_keys=True
        ) + "\n"
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

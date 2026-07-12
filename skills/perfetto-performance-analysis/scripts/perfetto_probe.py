#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from _common import (
    DEFAULT_MAX_OUTPUT_BYTES,
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

CAPABILITY_RECORDING_HINTS = {
    "slices": ("linux.ftrace", "track_event"),
    "thread_states": ("linux.ftrace", "sched/sched_switch"),
    "scheduling": ("linux.ftrace", "sched/sched_switch"),
    "counters": ("linux.sys_stats", "power/cpu_frequency", "track_event"),
    "frame_timeline": ("android.surfaceflinger.frametimeline",),
    "gpu": ("gpu.renderstages", "gpu.counters", "gpu.memory", "gpu_work_period"),
    "heap_graph": ("android.heapprofd",),
    "arguments": (),
}


def build_probe(
    trace: Path,
    rows: list[dict[str, str | int | float | None]],
    *,
    row_counts: dict[str, int] | None = None,
    recording_config: str | None = None,
    setup_errors: str | None = None,
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

    counts = row_counts or {}
    config = recording_config
    if config is None and isinstance(metadata.get("trace_config_pbtxt"), str):
        config = str(metadata["trace_config_pbtxt"])
    errors_text = setup_errors
    if errors_text is None and isinstance(metadata.get("ftrace_setup_errors"), str):
        errors_text = str(metadata["ftrace_setup_errors"])
    config_lower = config.lower() if isinstance(config, str) else None
    errors_lower = errors_text.lower() if isinstance(errors_text, str) else ""
    capabilities: dict[str, dict[str, object]] = {}
    for name, required in CAPABILITY_TABLES.items():
        schema_available = required.issubset(tables)
        observed_counts = {table: counts[table] for table in sorted(required) if table in counts}
        hints = CAPABILITY_RECORDING_HINTS[name]
        configured = (
            any(hint.lower() in config_lower for hint in hints)
            if config_lower is not None and hints
            else None
        )
        setup_error = any(hint.lower() in errors_lower for hint in hints)
        if not schema_available:
            state = "unsupported"
        elif observed_counts and any(value > 0 for value in observed_counts.values()):
            state = "recorded_populated"
        elif len(observed_counts) != len(required):
            state = "unknown"
        elif configured is True and not setup_error:
            state = "recorded_empty"
        elif configured is False:
            state = "not_recorded"
        else:
            state = "unknown"
        capabilities[name] = {
            "state": state,
            "schema_available": schema_available,
            "row_counts": observed_counts,
            "recording_config_known": config_lower is not None,
            "recording_configured": configured,
            "setup_error": setup_error,
            "usable_evidence": state == "recorded_populated",
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
        "available": sorted(
            name for name, capability in capabilities.items()
            if capability["state"] == "recorded_populated"
        ),
        "missing": sorted(
            name for name, capability in capabilities.items()
            if capability["state"] == "unsupported"
        ),
        "unknown": sorted(
            name for name, capability in capabilities.items()
            if capability["state"] == "unknown"
        ),
        "not_recorded": sorted(
            name for name, capability in capabilities.items()
            if capability["state"] == "not_recorded"
        ),
        "recorded_empty": sorted(
            name for name, capability in capabilities.items()
            if capability["state"] == "recorded_empty"
        ),
        "errors": errors,
    }


def probe_trace(
    trace: Path,
    *,
    trace_processor: str | None,
    timeout: float,
    max_output_bytes: int,
) -> dict[str, object]:
    result = run_query(
        trace,
        sql=PROBE_SQL,
        trace_processor=trace_processor,
        timeout=timeout,
        max_output_bytes=max_output_bytes,
    )
    rows = parse_csv_output(result.stdout)
    tables = {
        str(row["key"])
        for row in rows
        if row.get("section") == "table" and isinstance(row.get("key"), str)
    }
    row_counts: dict[str, int] = {}
    for table in sorted(set().union(*CAPABILITY_TABLES.values()) & tables):
        try:
            count_result = run_query(
                trace,
                sql=f'SELECT COUNT(*) AS row_count FROM "{table}";',
                trace_processor=trace_processor,
                timeout=timeout,
                max_output_bytes=max_output_bytes,
            )
            count_rows = parse_csv_output(count_result.stdout)
            if count_rows and isinstance(count_rows[0].get("row_count"), int):
                row_counts[table] = int(count_rows[0]["row_count"])
        except RuntimeError:
            continue
    return build_probe(trace, rows, row_counts=row_counts)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Probe trace identity, bounds, tables, metadata, and capabilities."
    )
    parser.add_argument("trace", type=Path)
    parser.add_argument("--trace-processor")
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument(
        "--max-output-bytes", type=int, default=DEFAULT_MAX_OUTPUT_BYTES
    )
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        probe = probe_trace(
            args.trace,
            trace_processor=args.trace_processor,
            timeout=args.timeout,
            max_output_bytes=args.max_output_bytes,
        )
        rendered = json.dumps(
            probe, ensure_ascii=False, indent=2, sort_keys=True
        ) + "\n"
        if args.output:
            write_text_atomic(args.output, rendered)
        else:
            sys.stdout.write(rendered)
        return 0
    except (FileNotFoundError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

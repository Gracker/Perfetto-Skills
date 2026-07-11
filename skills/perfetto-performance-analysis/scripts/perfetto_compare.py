#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys
from typing import Any

from _common import write_text_atomic


SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
METRIC_STATES = {"observed", "not_observed", "missing_evidence", "out_of_scope"}


def require_mapping(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object")
    return value


def validate_side(label: str, document: dict[str, Any]) -> None:
    if document.get("schema_version") != 1:
        raise ValueError(f"side {label!r} has unsupported schema_version")
    trace = require_mapping(document.get("trace"), f"side {label} trace")
    sha256 = trace.get("sha256")
    if not isinstance(sha256, str) or not SHA256_PATTERN.fullmatch(sha256):
        raise ValueError(f"side {label!r} trace.sha256 is invalid")
    metrics = require_mapping(document.get("metrics"), f"side {label} metrics")
    for key, raw_metric in metrics.items():
        metric = require_mapping(raw_metric, f"side {label} metric {key}")
        status = metric.get("status")
        if status not in METRIC_STATES:
            raise ValueError(f"side {label} metric {key} has invalid status")
        if status == "observed":
            value = metric.get("value")
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                raise ValueError(f"side {label} metric {key} needs a numeric value")
            if not math.isfinite(float(value)):
                raise ValueError(f"side {label} metric {key} needs a finite value")
        for field in ("unit", "definition"):
            if not isinstance(metric.get(field), str) or not metric[field]:
                raise ValueError(f"side {label} metric {key} needs {field}")
        refs = metric.get("evidence_refs", [])
        if not isinstance(refs, list) or not all(isinstance(ref, str) for ref in refs):
            raise ValueError(f"side {label} metric {key} evidence_refs must be strings")
    limitations = document.get("limitations", [])
    if not isinstance(limitations, list) or not all(
        isinstance(item, str) for item in limitations
    ):
        raise ValueError(f"side {label} limitations must be strings")


def build_comparison(
    sides: list[tuple[str, Path, dict[str, Any]]],
    *,
    baseline: str,
    metric_keys: list[str] | None,
) -> dict[str, Any]:
    if len(sides) < 2:
        raise ValueError("comparison requires at least two sides")
    labels = [label for label, _, _ in sides]
    if len(labels) != len(set(labels)):
        raise ValueError("duplicate side labels are not allowed")
    if baseline not in labels:
        raise ValueError(f"baseline side is missing: {baseline}")
    for label, _, document in sides:
        validate_side(label, document)

    all_keys = sorted(
        set().union(
            *(
                set(require_mapping(document["metrics"], "metrics"))
                for _, _, document in sides
            )
        )
    )
    keys = [key for key in all_keys if metric_keys is None or key in metric_keys]
    unknown = sorted(set(metric_keys or []) - set(all_keys))
    if unknown:
        raise ValueError(f"requested metrics are absent from every side: {unknown}")

    rows: list[dict[str, Any]] = []
    limitations: list[str] = []
    for key in keys:
        entries = {
            label: require_mapping(document["metrics"], "metrics").get(key)
            for label, _, document in sides
        }
        missing = [label for label, entry in entries.items() if entry is None]
        observed = {
            label: entry
            for label, entry in entries.items()
            if isinstance(entry, dict) and entry.get("status") == "observed"
        }
        units = {entry["unit"] for entry in observed.values()}
        definitions = {entry["definition"] for entry in observed.values()}
        reason: str | None = None
        if missing:
            reason = f"metric missing on sides: {', '.join(missing)}"
        elif len(observed) != len(sides):
            unavailable = [
                f"{label}={entries[label].get('status')}"
                for label in labels
                if label not in observed
            ]
            reason = "metric unavailable: " + ", ".join(unavailable)
        elif len(units) != 1:
            reason = "unit mismatch across sides"
        elif len(definitions) != 1:
            reason = "definition mismatch across sides"
        comparable = reason is None
        values = {
            label: entry.get("value") if isinstance(entry, dict) else None
            for label, entry in entries.items()
        }
        deltas: dict[str, dict[str, float | None]] = {}
        if comparable:
            baseline_value = float(values[baseline])
            for label in labels:
                value = float(values[label])
                absolute = value - baseline_value
                percent = None if baseline_value == 0 else absolute / baseline_value * 100
                deltas[label] = {
                    "absolute": round(absolute, 9),
                    "percent": None if percent is None else round(percent, 9),
                }
        else:
            limitations.append(f"{key}: {reason}")
        rows.append(
            {
                "key": key,
                "unit": next(iter(units)) if len(units) == 1 else None,
                "definition": next(iter(definitions)) if len(definitions) == 1 else None,
                "comparable": comparable,
                "reason": reason,
                "values": values,
                "deltas": deltas,
                "evidence_refs": {
                    label: entry.get("evidence_refs", [])
                    if isinstance(entry, dict)
                    else []
                    for label, entry in entries.items()
                },
            }
        )

    for label, _, document in sides:
        limitations.extend(f"{label}: {item}" for item in document.get("limitations", []))
    return {
        "schema_version": 1,
        "workflow": "trace-comparison",
        "status": "complete" if all(row["comparable"] for row in rows) else "partial",
        "baseline": baseline,
        "sides": [
            {"label": label, "path": str(path), "trace": document["trace"]}
            for label, path, document in sides
        ],
        "metrics": rows,
        "limitations": limitations,
    }


def load_side(specification: str) -> tuple[str, Path, dict[str, Any]]:
    label, separator, raw_path = specification.partition("=")
    if not separator or not label or not raw_path:
        raise ValueError("--side must use LABEL=PATH")
    path = Path(raw_path).expanduser().resolve()
    def reject_non_finite(value: str) -> None:
        raise ValueError(f"side {label} contains non-finite JSON number: {value}")

    document = require_mapping(
        json.loads(
            path.read_text(encoding="utf-8"), parse_constant=reject_non_finite
        ),
        f"side {label}",
    )
    return label, path, document


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Compare file-based Perfetto evidence summaries without product services."
    )
    parser.add_argument("--side", action="append", required=True, metavar="LABEL=PATH")
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--metric", action="append", dest="metrics")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        result = build_comparison(
            [load_side(specification) for specification in args.side],
            baseline=args.baseline,
            metric_keys=args.metrics,
        )
        rendered = (
            json.dumps(
                result,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
                allow_nan=False,
            )
            + "\n"
        )
        if args.output:
            write_text_atomic(args.output, rendered)
        else:
            sys.stdout.write(rendered)
        return 0
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

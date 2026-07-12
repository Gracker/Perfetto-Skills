#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from runtime.report import validate_report_payload


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate a Perfetto Skills report v2.")
    parser.add_argument("report", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.report.read_text(encoding="utf-8"))
        issues = validate_report_payload(report)
        if issues:
            print(json.dumps({"status": "invalid", "issues": issues}, ensure_ascii=False, indent=2))
            return 2
        print(json.dumps({"status": "valid", "issues": []}, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

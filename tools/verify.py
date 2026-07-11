#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def build_commands() -> list[list[str]]:
    return [
        [
            sys.executable,
            "-m",
            "unittest",
            "discover",
            "-s",
            "tests",
            "-p",
            "test_*.py",
        ],
        [
            "agentskills",
            "validate",
            "skills/perfetto-performance-analysis",
        ],
    ]


def run(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the configured Perfetto Skills verification gate."
    )
    parser.add_argument(
        "--smartperfetto",
        type=Path,
        help="Path to a SmartPerfetto checkout for export and trace verification.",
    )
    parser.parse_args()
    for command in build_commands():
        run(command)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

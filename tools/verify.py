#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def build_commands(smartperfetto: Path | None = None) -> list[list[str]]:
    commands = [
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
    if smartperfetto is not None:
        commands.extend(
            [
                [
                    sys.executable,
                    "tools/export_from_smartperfetto.py",
                    "--source",
                    str(smartperfetto),
                    "--check",
                ],
                [
                    sys.executable,
                    "tools/validate_catalog.py",
                    "--catalog",
                    "catalog/smartperfetto-export.json",
                    "--skill-root",
                    "skills/perfetto-performance-analysis",
                ],
            ]
        )
    return commands


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
    args = parser.parse_args()
    source = args.smartperfetto.expanduser().resolve() if args.smartperfetto else None
    for command in build_commands(source):
        run(command)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

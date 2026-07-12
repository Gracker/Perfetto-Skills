#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections.abc import Mapping
import os
import platform
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
        commands = [
            [
                sys.executable,
                "tools/download_declared_fixtures.py",
                "--smartperfetto",
                str(smartperfetto),
            ],
            *commands,
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
    return commands


def smartperfetto_environment(
    source: Path,
    *,
    system: str | None = None,
    machine: str | None = None,
    base: Mapping[str, str] | None = None,
) -> dict[str, str]:
    source = source.expanduser().resolve()
    traces = source / "test-traces"
    if not traces.is_dir():
        raise FileNotFoundError(f"SmartPerfetto test traces are missing: {traces}")
    host = (system or platform.system()).lower()
    architecture = (machine or platform.machine()).lower()
    aliases = {
        ("darwin", "arm64"): ("darwin-arm64", "trace_processor_shell"),
        ("darwin", "aarch64"): ("darwin-arm64", "trace_processor_shell"),
        ("linux", "x86_64"): ("linux-x64", "trace_processor_shell"),
        ("linux", "amd64"): ("linux-x64", "trace_processor_shell"),
        ("windows", "x86_64"): ("win32-x64", "trace_processor_shell.exe"),
        ("windows", "amd64"): ("win32-x64", "trace_processor_shell.exe"),
    }
    if (host, architecture) not in aliases:
        raise RuntimeError(f"No SmartPerfetto prebuilt for {host}-{architecture}")
    directory, filename = aliases[(host, architecture)]
    binary = (
        source
        / "backend"
        / "prebuilts"
        / "trace_processor"
        / directory
        / filename
    )
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise FileNotFoundError(f"SmartPerfetto trace processor is not executable: {binary}")
    environment = dict(os.environ if base is None else base)
    environment.update(
        {
            "SMARTPERFETTO_SOURCE": str(source),
            "SMARTPERFETTO_TEST_TRACES": str(traces.resolve()),
            "PERFETTO_TRACE_PROCESSOR": str(binary.resolve()),
        }
    )
    return environment


def run(command: list[str], *, env: Mapping[str, str] | None = None) -> None:
    completed = subprocess.run(command, cwd=ROOT, check=False, env=env)
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
    environment = smartperfetto_environment(source) if source is not None else None
    for command in build_commands(source):
        run(command, env=environment)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

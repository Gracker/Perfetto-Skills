#!/usr/bin/env python3
"""Run the complete independent Perfetto-Skills verification gate."""

from __future__ import annotations

import argparse
from collections.abc import Mapping
import json
import os
from pathlib import Path
import subprocess
import sys
import re

try:
    from tools.download_fixture_pack import download_pack
    from tools.fixture_manifest import load_manifest, sha256_file
except ModuleNotFoundError:  # Direct script execution.
    from download_fixture_pack import download_pack
    from fixture_manifest import load_manifest, sha256_file


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"
FIXTURE_MANIFEST = ROOT / "fixtures" / "manifest.json"
FIXTURE_LOCK = ROOT / "upstreams" / "fixture-pack.lock.json"


def build_commands(smartperfetto: Path | None = None) -> list[list[str]]:
    commands = [
        [sys.executable, "tools/upstream_locks.py"],
        [sys.executable, "tools/compile_skill.py", "--check"],
        [sys.executable, "tools/validate_all_queries.py", "--execute"],
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
        ["agentskills", "validate", "skills/perfetto-performance-analysis"],
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


def verification_environment(
    fixtures: Path,
    processor: Path,
    *,
    tier: str,
    base: Mapping[str, str] | None = None,
) -> dict[str, str]:
    fixtures = fixtures.expanduser().resolve()
    processor = processor.expanduser().resolve()
    if not fixtures.is_dir():
        raise FileNotFoundError(f"fixture root is missing: {fixtures}")
    if not processor.is_file() or not os.access(processor, os.X_OK):
        raise FileNotFoundError(f"trace processor is not executable: {processor}")
    environment = dict(os.environ if base is None else base)
    environment.update(
        {
            "PERFETTO_FIXTURE_ROOT": str(fixtures),
            "PERFETTO_FIXTURE_TIER": tier,
            "PERFETTO_TRACE_PROCESSOR": str(processor),
        }
    )
    environment.pop("SMARTPERFETTO_TEST_TRACES", None)
    return environment


def _verify_fixture_root(root: Path, *, offline: bool) -> Path:
    manifest = load_manifest(FIXTURE_MANIFEST)
    fixtures = manifest["fixtures"]
    if offline:
        fixtures = [
            fixture
            for fixture in fixtures
            if fixture["id"] == "startup-api32-warm-smoke"
        ]
    for fixture in fixtures:
        path = root / fixture["path"]
        if not path.is_file() or sha256_file(path) != fixture["sha256"]:
            raise ValueError(f"owned fixture is missing or invalid: {fixture['id']}")
    return root


def resolve_fixture_root(
    explicit: Path | None,
    *,
    offline: bool,
    cache: Path,
) -> Path:
    if offline:
        return _verify_fixture_root(ROOT / "fixtures", offline=True)
    if explicit is not None:
        return _verify_fixture_root(explicit.expanduser().resolve(), offline=False)
    return download_pack(FIXTURE_LOCK, cache)


def resolve_trace_processor(cache: Path) -> Path:
    configured = os.environ.get("PERFETTO_TRACE_PROCESSOR")
    if configured:
        path = Path(configured).expanduser().resolve()
        if not path.is_file() or not os.access(path, os.X_OK):
            raise FileNotFoundError(f"trace processor is not executable: {path}")
        validate_trace_processor(path)
        return path
    completed = subprocess.run(
        [
            sys.executable,
            str(SKILL / "scripts/bootstrap_trace_processor.py"),
            "--cache-dir",
            str(cache),
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    path = Path(completed.stdout.strip()).resolve()
    validate_trace_processor(path)
    return path


def validate_processor_identity(output: str, lock: dict[str, object]) -> None:
    version_line = re.search(r"Perfetto (v[^ ]+) \(([0-9a-f]{40})\)", output)
    rpc_line = re.search(r"Trace Processor RPC API version: (\d+)", output)
    if version_line is None or rpc_line is None:
        raise ValueError("trace processor did not report version/commit/RPC identity")
    reported_version = version_line.group(1).split("-", 1)[0]
    if reported_version != lock["tag"] or version_line.group(2) != lock["commit"]:
        raise ValueError("trace processor version or commit differs from lock")
    if int(rpc_line.group(1)) != lock["rpc_api_version"]:
        raise ValueError("trace processor RPC API differs from lock")


def validate_trace_processor(path: Path) -> None:
    lock = json.loads((ROOT / "upstreams/google-perfetto.lock.json").read_text(encoding="utf-8"))
    completed = subprocess.run(
        [str(path), "--version"],
        check=True,
        capture_output=True,
        text=True,
    )
    validate_processor_identity(completed.stdout, lock)


def run(command: list[str], *, env: Mapping[str, str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, check=False, env=env)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--smartperfetto",
        type=Path,
        help="Explicit SmartPerfetto checkout used only for import drift checks.",
    )
    parser.add_argument("--fixtures", type=Path, help="Verified owned fixture root.")
    parser.add_argument("--offline", action="store_true", help="Use only the committed smoke trace.")
    parser.add_argument(
        "--fixture-cache",
        type=Path,
        default=Path(os.environ.get("PERFETTO_FIXTURE_CACHE", ROOT / ".perfetto-fixtures")),
    )
    parser.add_argument(
        "--processor-cache",
        type=Path,
        default=Path.home() / ".cache" / "perfetto-skills",
    )
    args = parser.parse_args(arguments)
    if args.offline and args.fixtures:
        parser.error("--offline and --fixtures are mutually exclusive")

    processor = resolve_trace_processor(args.processor_cache)
    fixtures = resolve_fixture_root(
        args.fixtures,
        offline=args.offline,
        cache=args.fixture_cache,
    )
    environment = verification_environment(
        fixtures,
        processor,
        tier="offline" if args.offline else "full",
    )
    source = args.smartperfetto.expanduser().resolve() if args.smartperfetto else None
    if source is not None:
        environment["SMARTPERFETTO_SOURCE"] = str(source)
    for command in build_commands(source):
        run(command, env=environment)
    print(
        json.dumps(
            {
                "status": "verified",
                "fixture_tier": environment["PERFETTO_FIXTURE_TIER"],
                "fixture_root": environment["PERFETTO_FIXTURE_ROOT"],
                "trace_processor": environment["PERFETTO_TRACE_PROCESSOR"],
                "smartperfetto_sync": str(source) if source else None,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

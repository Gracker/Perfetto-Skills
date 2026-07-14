#!/usr/bin/env python3
"""Index a pinned official PerfettoSQL stdlib and intrinsic schema substrate."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

try:
    from tools.upstream_locks import load_and_validate_google_lock
except ModuleNotFoundError:  # Direct script execution.
    from upstream_locks import load_and_validate_google_lock


ROOT = Path(__file__).resolve().parents[1]
STDLIB = "src/trace_processor/perfetto_sql/stdlib"
INTRINSIC = "src/trace_processor/tables"
SYMBOL = re.compile(
    r"\bCREATE\s+PERFETTO\s+(TABLE|VIEW|FUNCTION|MACRO|INDEX)\s+([A-Za-z_][A-Za-z0-9_.$]*)",
    re.IGNORECASE,
)
RPC = re.compile(r"TRACE_PROCESSOR_CURRENT_API_VERSION\s*=\s*(\d+)")


def _git(repository: Path, *arguments: str, text: bool = True) -> str | bytes:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=True,
        capture_output=True,
        text=text,
    ).stdout


def _paths(repository: Path, revision: str, prefix: str) -> list[str]:
    return sorted(
        path
        for path in str(
            _git(repository, "ls-tree", "-r", "--name-only", revision, prefix)
        ).splitlines()
        if path
    )


def _bytes(repository: Path, revision: str, path: str) -> bytes:
    value = _git(repository, "show", f"{revision}:{path}", text=False)
    assert isinstance(value, bytes)
    return value


def build_stdlib_index(perfetto: Path, revision: str) -> dict[str, object]:
    commit = str(_git(perfetto, "rev-parse", f"{revision}^{{commit}}")).strip()
    tree = str(_git(perfetto, "rev-parse", f"{revision}:{STDLIB}")).strip()
    modules = []
    warnings = []
    for path in _paths(perfetto, revision, STDLIB):
        if not path.endswith(".sql"):
            continue
        payload = _bytes(perfetto, revision, path)
        text = payload.decode("utf-8")
        sql_without_line_comments = re.sub(r"--[^\n]*", "", text)
        symbols = [
            {"kind": match.group(1).upper(), "name": match.group(2)}
            for match in SYMBOL.finditer(sql_without_line_comments)
        ]
        create_count = len(
            re.findall(
                r"\bCREATE\s+PERFETTO\b",
                sql_without_line_comments,
                re.IGNORECASE,
            )
        )
        if create_count != len(symbols):
            warnings.append(
                {
                    "path": path,
                    "reason": "unparsed CREATE PERFETTO construct",
                    "count": create_count - len(symbols),
                }
            )
        comments = []
        for line in text.splitlines():
            if line.startswith("--"):
                comments.append(line.removeprefix("--").strip())
            elif line.strip():
                break
        modules.append(
            {
                "module": path.removeprefix(STDLIB + "/").removesuffix(".sql").replace("/", "."),
                "path": path,
                "sha256": hashlib.sha256(payload).hexdigest(),
                "symbols": symbols,
                "doc": " ".join(comments),
            }
        )
    intrinsic = []
    for path in _paths(perfetto, revision, INTRINSIC):
        if not path.endswith(".py"):
            continue
        payload = _bytes(perfetto, revision, path)
        intrinsic.append(
            {"path": path, "sha256": hashlib.sha256(payload).hexdigest()}
        )
    return {
        "schema_version": 1,
        "revision": revision,
        "commit": commit,
        "stdlib_tree": tree,
        "modules": modules,
        "intrinsic_schema_sources": intrinsic,
        "parse_warnings": warnings,
    }


def compare_stdlib(old: dict[str, object], new: dict[str, object]) -> dict[str, list[str]]:
    before = {item["module"]: item["sha256"] for item in old.get("modules", [])}
    after = {item["module"]: item["sha256"] for item in new.get("modules", [])}
    return {
        "added": sorted(set(after) - set(before)),
        "removed": sorted(set(before) - set(after)),
        "changed": sorted(
            module for module in set(before) & set(after) if before[module] != after[module]
        ),
    }


def _validate_release(perfetto: Path, lock: dict[str, object]) -> None:
    tag = str(lock["tag"])
    if str(_git(perfetto, "rev-parse", f"{tag}^{{}}")).strip() != lock["commit"]:
        raise ValueError("Perfetto tag and peeled commit differ")
    if str(_git(perfetto, "rev-parse", f"{tag}:{STDLIB}")).strip() != lock["stdlib_tree"]:
        raise ValueError("Perfetto stdlib tree differs from lock")
    proto = _bytes(
        perfetto, tag, "protos/perfetto/trace_processor/trace_processor.proto"
    ).decode("utf-8")
    match = RPC.search(proto)
    if match is None or int(match.group(1)) != lock["rpc_api_version"]:
        raise ValueError("Perfetto RPC API differs from lock")


def release_identity(perfetto: Path, revision: str) -> dict[str, object]:
    proto = _bytes(
        perfetto, revision, "protos/perfetto/trace_processor/trace_processor.proto"
    ).decode("utf-8")
    match = RPC.search(proto)
    if match is None:
        raise ValueError("Perfetto RPC API version is missing")
    return {
        "revision": revision,
        "commit": str(_git(perfetto, "rev-parse", f"{revision}^{{commit}}")).strip(),
        "stdlib_tree": str(_git(perfetto, "rev-parse", f"{revision}:{STDLIB}")).strip(),
        "rpc_api_version": int(match.group(1)),
    }


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--perfetto", required=True, type=Path)
    parser.add_argument("--lock", type=Path, default=ROOT / "upstreams/google-perfetto.lock.json")
    parser.add_argument("--report-dir", type=Path, default=ROOT / "test-output/sync")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument(
        "--revision",
        help="Inventory a release for canary review without changing the pinned lock",
    )
    args = parser.parse_args(arguments)
    lock = load_and_validate_google_lock(
        args.lock, validate_snapshots=not args.apply
    )
    revision = args.revision or lock["tag"]
    if args.revision is None:
        _validate_release(args.perfetto, lock)
    if args.apply and args.revision is not None:
        raise ValueError("canary revision cannot be applied without updating the lock")
    identity = release_identity(args.perfetto, revision)
    current = build_stdlib_index(args.perfetto, revision)
    if current["parse_warnings"]:
        raise ValueError(
            f"stdlib index has {len(current['parse_warnings'])} parse warnings"
        )
    snapshot_path = ROOT / "upstreams/snapshots/google-perfetto/stdlib-index.json"
    previous = (
        json.loads(snapshot_path.read_text(encoding="utf-8"))
        if snapshot_path.is_file()
        else {"modules": []}
    )
    report = {
        "schema_version": 1,
        "previous_commit": previous.get("commit"),
        "current_commit": current["commit"],
        "candidate_identity": identity,
        "lock_compatible": {
            "commit": identity["commit"] == lock["commit"],
            "stdlib_tree": identity["stdlib_tree"] == lock["stdlib_tree"],
            "rpc_api_version": identity["rpc_api_version"] == lock["rpc_api_version"],
        },
        "drift": compare_stdlib(previous, current),
        "intrinsic_schema_source_count": len(current["intrinsic_schema_sources"]),
    }
    args.report_dir.mkdir(parents=True, exist_ok=True)
    report_path = args.report_dir / "perfetto-stdlib-drift.json"
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if args.apply:
        snapshot_path.parent.mkdir(parents=True, exist_ok=True)
        snapshot_path.write_text(
            json.dumps(current, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        lock["stdlib_snapshot_sha256"] = hashlib.sha256(
            snapshot_path.read_bytes()
        ).hexdigest()
        args.lock.write_text(
            json.dumps(lock, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        committed_report = ROOT / "upstreams/reports/perfetto-stdlib-drift.json"
        committed_report.parent.mkdir(parents=True, exist_ok=True)
        committed_report.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    print(report_path)
    if args.revision is not None and (
        any(report["drift"].values())
        or not all(report["lock_compatible"].values())
    ):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

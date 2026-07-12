#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

from _common import resolve_trace_processor, runtime_platform_key, sha256_file, write_text_atomic


SOURCE_LOCK = Path("references/generated/runtime/perfetto-source-lock.json")


def verify_binary_identity(
    *,
    version_text: str,
    binary_sha256: str,
    platform_key: str,
    source_lock: dict[str, object],
) -> dict[str, object]:
    release = source_lock["release"]
    platforms = source_lock["runtime_substrate"]["platforms"]
    expected_platform = platforms.get(platform_key)
    issues: list[str] = []
    if expected_platform is None:
        issues.append(f"platform is not locked: {platform_key}")
    elif binary_sha256 != expected_platform["sha256"]:
        issues.append("binary SHA-256 does not match the release lock")
    if str(release["commit"]) not in version_text:
        issues.append("trace processor commit does not match the release lock")
    rpc_match = re.search(r"RPC(?: API(?: version)?)?\D+(\d+)", version_text, flags=re.I)
    if not rpc_match or int(rpc_match.group(1)) != int(release["rpc_api_version"]):
        issues.append("trace processor RPC API does not match the release lock")
    return {
        "status": "verified" if not issues else "unsupported",
        "platform": platform_key,
        "binary_sha256": binary_sha256,
        "version": version_text.strip(),
        "issues": issues,
    }


def load_source_lock(skill_root: Path) -> dict[str, object]:
    return json.loads((skill_root / SOURCE_LOCK).read_text(encoding="utf-8"))


def inspect_binary_identity(
    binary: Path,
    *,
    source_lock: dict[str, object],
) -> dict[str, object]:
    completed = subprocess.run(
        [str(binary), "--version"], check=False, capture_output=True, text=True
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or "trace processor --version failed")
    return verify_binary_identity(
        version_text=completed.stdout + completed.stderr,
        binary_sha256=sha256_file(binary),
        platform_key=runtime_platform_key(),
        source_lock=source_lock,
    )


def require_verified_identity(
    result: dict[str, object], *, allow_unsupported: bool
) -> dict[str, object]:
    if result["status"] == "verified" or allow_unsupported:
        return result
    issues = "; ".join(str(issue) for issue in result.get("issues", []))
    raise RuntimeError(
        "unsupported trace processor: "
        + (issues or "identity does not match the Perfetto release lock")
    )


def resolve_verified_processor(
    requested: str | None,
    *,
    skill_root: Path,
    allow_unsupported: bool = False,
) -> tuple[Path, dict[str, object]]:
    binary = resolve_trace_processor(requested)
    result = inspect_binary_identity(binary, source_lock=load_source_lock(skill_root))
    require_verified_identity(result, allow_unsupported=allow_unsupported)
    return binary, result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify the trace processor identity used by Perfetto Skills."
    )
    parser.add_argument("--trace-processor")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        skill_root = Path(__file__).resolve().parents[1]
        binary = resolve_trace_processor(args.trace_processor)
        result = inspect_binary_identity(
            binary,
            source_lock=load_source_lock(skill_root),
        )
        rendered = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        if args.output:
            write_text_atomic(args.output, rendered)
        else:
            sys.stdout.write(rendered)
        return 0 if result["status"] == "verified" else 2
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
from collections.abc import Callable
from typing import BinaryIO
from urllib.request import urlopen

from _common import default_cache_root, runtime_platform_key


SKILL_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOCK = SKILL_ROOT / "references" / "trace-processor-lock.json"


def platform_key(system: str | None = None, machine: str | None = None) -> str:
    return runtime_platform_key(system, machine)


def load_lock(path: str | Path = DEFAULT_LOCK) -> dict[str, object]:
    lock_path = Path(path).expanduser().resolve()
    data = json.loads(lock_path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise ValueError(f"Unsupported trace processor lock schema: {lock_path}")
    if not isinstance(data.get("platforms"), dict):
        raise ValueError(f"Lock file has no platform map: {lock_path}")
    return data


def verify_sha256(path: str | Path, expected: str) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest()
    if actual.lower() != expected.lower():
        raise ValueError(
            f"SHA-256 mismatch for {path}: expected {expected.lower()}, got {actual}"
        )
    return actual


def install_locked_binary(
    lock: dict[str, object],
    key: str,
    cache_root: Path,
    *,
    opener: Callable[[str], BinaryIO] = urlopen,
    force: bool = False,
) -> Path:
    platforms = lock["platforms"]
    if not isinstance(platforms, dict) or key not in platforms:
        raise RuntimeError(f"Unsupported platform in lock file: {key}")
    entry = platforms[key]
    if not isinstance(entry, dict):
        raise ValueError(f"Invalid lock entry for {key}")
    relative_path = str(entry["path"])
    expected_hash = str(entry["sha256"])
    version = str(lock["perfetto_version"])
    base_url = str(lock["base_url"]).rstrip("/")
    destination = (
        Path(cache_root).expanduser().resolve()
        / "trace_processor"
        / version
        / key
        / Path(relative_path).name
    )
    destination.parent.mkdir(parents=True, exist_ok=True)

    if destination.exists():
        try:
            verify_sha256(destination, expected_hash)
            return destination
        except ValueError:
            if not force:
                raise

    url = f"{base_url}/{relative_path.lstrip('/')}"
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", dir=destination.parent, delete=False
        ) as output:
            temporary = Path(output.name)
            with opener(url) as response:
                shutil.copyfileobj(response, output)
        verify_sha256(temporary, expected_hash)
        if os.name != "nt":
            temporary.chmod(0o755)
        os.replace(temporary, destination)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download and verify an official trace_processor_shell prebuilt."
    )
    parser.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--cache-dir", type=Path, default=default_cache_root())
    parser.add_argument("--platform", dest="platform_name")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    lock = load_lock(args.lock)
    key = args.platform_name or platform_key()
    installed = install_locked_binary(
        lock, key, args.cache_dir, force=args.force
    )
    print(installed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


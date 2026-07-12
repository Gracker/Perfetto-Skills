#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tempfile
from typing import BinaryIO, Callable
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = (
    ROOT
    / "skills"
    / "perfetto-performance-analysis"
    / "references"
    / "generated"
    / "runtime"
    / "fixture-manifest.json"
)
PERFETTO_TEST_DATA_BASE = "https://storage.googleapis.com/perfetto/test_data"


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def download_declared_fixtures(
    manifest_path: Path,
    smartperfetto: Path,
    *,
    opener: Callable[[str], BinaryIO] = urlopen,
) -> list[Path]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    source_root = smartperfetto.expanduser().resolve()
    downloaded: list[Path] = []
    for fixture in manifest["fixtures"]:
        if not fixture.get("assertions"):
            continue
        relative = PurePosixPath(str(fixture["source"]))
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"unsafe fixture path: {relative}")
        target = source_root.joinpath(*relative.parts)
        expected = str(fixture["sha256"])
        if target.is_file():
            if _sha256(target.read_bytes()) != expected:
                raise ValueError(f"fixture checksum mismatch: {relative}")
            continue
        if relative.parts[:3] != ("perfetto", "test", "data"):
            raise FileNotFoundError(f"declared fixture is missing: {relative}")
        url = f"{PERFETTO_TEST_DATA_BASE}/{relative.name}-{expected}"
        with opener(url) as response:
            payload = response.read()
        if _sha256(payload) != expected:
            raise ValueError(f"downloaded fixture checksum mismatch: {relative}")
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as handle:
            handle.write(payload)
            temporary = Path(handle.name)
        try:
            os.replace(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)
        downloaded.append(target)
    return downloaded


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Download only upstream Perfetto fixtures declared by Perfetto Skills."
    )
    parser.add_argument("--smartperfetto", required=True, type=Path)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args(argv)
    for path in download_declared_fixtures(args.manifest, args.smartperfetto):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

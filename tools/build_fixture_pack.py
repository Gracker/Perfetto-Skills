#!/usr/bin/env python3
"""Build a deterministic Perfetto-Skills real-trace fixture archive."""

from __future__ import annotations

import argparse
import gzip
from io import BytesIO
import json
from pathlib import Path
import tarfile

try:
    from tools.fixture_manifest import load_manifest, sha256_file, validate_manifest
except ModuleNotFoundError:  # Direct script execution.
    from fixture_manifest import load_manifest, sha256_file, validate_manifest


def _tar_info(name: str, size: int) -> tarfile.TarInfo:
    info = tarfile.TarInfo(name)
    info.size = size
    info.mtime = 0
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    info.mode = 0o644
    return info


EVIDENCE_MEMBERS = {
    "privacy-scan-v2.json": "privacy-scan-v2.json",
    "LICENSES/AGPL-3.0.txt": "licenses/AGPL-3.0.txt",
    "LICENSES/Apache-2.0.txt": "licenses/Apache-2.0.txt",
    "NOTICE": "NOTICE",
}


def _validated_evidence(manifest: dict[str, object], fixture_root: Path) -> list[tuple[str, bytes]]:
    privacy_path = fixture_root / EVIDENCE_MEMBERS["privacy-scan-v2.json"]
    privacy = json.loads(privacy_path.read_text(encoding="utf-8"))
    if privacy.get("ruleset") != "fixture-privacy-v2":
        raise ValueError("fixture privacy report must use fixture-privacy-v2")
    expected = {fixture["sha256"] for fixture in manifest["fixtures"]}
    results = privacy.get("results")
    if not isinstance(results, list) or {result.get("sha256") for result in results} != expected:
        raise ValueError("fixture privacy report does not cover the exact manifest")
    for result in results:
        review = result.get("identifier_review", {})
        if result.get("passed") is not True or review.get("status") != "approved":
            raise ValueError("fixture privacy and identifier review must pass")
    entries = []
    for archive_name, relative in EVIDENCE_MEMBERS.items():
        source = fixture_root / relative
        if source.is_symlink() or not source.is_file():
            raise ValueError(f"fixture evidence is missing: {relative}")
        entries.append((archive_name, source.read_bytes()))
    return entries


def build_pack(manifest_path: Path, source_root: Path, output: Path) -> Path:
    manifest = load_manifest(manifest_path)
    issues = validate_manifest(manifest)
    if issues:
        raise ValueError("invalid fixture manifest: " + "; ".join(issues))

    fixture_root = manifest_path.parent
    entries: list[tuple[str, bytes]] = [
        ("manifest.json", manifest_path.read_bytes()),
        *_validated_evidence(manifest, fixture_root),
    ]
    for fixture in manifest["fixtures"]:
        relative = fixture["path"]
        source = source_root / relative
        if source.is_symlink() or not source.is_file():
            raise ValueError(f"fixture must be a regular file: {relative}")
        if sha256_file(source) != fixture["sha256"]:
            raise ValueError(f"fixture checksum mismatch: {relative}")
        entries.append((relative, source.read_bytes()))

    tar_buffer = BytesIO()
    with tarfile.open(fileobj=tar_buffer, mode="w", format=tarfile.PAX_FORMAT) as archive:
        for name, payload in sorted(entries):
            archive.addfile(_tar_info(name, len(payload)), BytesIO(payload))

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as raw:
        with gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=0) as compressed:
            compressed.write(tar_buffer.getvalue())
    return output


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path("fixtures/manifest.json"))
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(arguments)
    result = build_pack(args.manifest, args.source_root, args.output)
    print(f"{sha256_file(result)}  {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

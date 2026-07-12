#!/usr/bin/env python3
"""Download and atomically verify a pinned Perfetto-Skills fixture pack."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tarfile
import tempfile
from typing import BinaryIO, Callable
from urllib.request import urlopen

try:
    from tools.build_fixture_pack import EVIDENCE_MEMBERS
    from tools.fixture_manifest import load_manifest, sha256_file, validate_manifest
except ModuleNotFoundError:  # Direct script execution.
    from build_fixture_pack import EVIDENCE_MEMBERS
    from fixture_manifest import load_manifest, sha256_file, validate_manifest


def _safe_member(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(name) and not path.is_absolute() and ".." not in path.parts


def _verify_root(root: Path, lock: dict[str, object]) -> None:
    manifest_path = root / "manifest.json"
    if not manifest_path.is_file() or sha256_file(manifest_path) != lock["manifest_sha256"]:
        raise ValueError("fixture manifest checksum mismatch")
    manifest = load_manifest(manifest_path)
    issues = validate_manifest(manifest)
    if issues:
        raise ValueError("invalid fixture manifest: " + "; ".join(issues))
    expected = {
        "manifest.json",
        *EVIDENCE_MEMBERS,
        *(fixture["path"] for fixture in manifest["fixtures"]),
    }
    actual = {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
    }
    if actual != expected:
        raise ValueError(
            f"fixture cache members differ: missing={sorted(expected - actual)}, "
            f"extra={sorted(actual - expected)}"
        )
    for fixture in manifest["fixtures"]:
        path = root / fixture["path"]
        if path.is_symlink() or sha256_file(path) != fixture["sha256"]:
            raise ValueError(f"fixture checksum mismatch: {fixture['path']}")
    evidence_hashes = lock.get("evidence_sha256")
    if not isinstance(evidence_hashes, dict) or set(evidence_hashes) != set(EVIDENCE_MEMBERS):
        raise ValueError("fixture evidence checksums are incomplete")
    for name, expected_sha256 in evidence_hashes.items():
        if sha256_file(root / name) != expected_sha256:
            raise ValueError(f"fixture evidence checksum mismatch: {name}")


def download_pack(
    lock_path: Path,
    cache_root: Path,
    *,
    opener: Callable[[str], BinaryIO] = urlopen,
) -> Path:
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    version = lock.get("version")
    if not isinstance(version, str) or not version:
        raise ValueError("fixture lock version is required")
    cache_root.mkdir(parents=True, exist_ok=True)
    target = cache_root / version
    if target.is_dir():
        try:
            _verify_root(target, lock)
            return target
        except ValueError:
            shutil.rmtree(target)

    lock_directory = cache_root / f".{version}.lock"
    try:
        lock_directory.mkdir()
    except FileExistsError as error:
        raise RuntimeError(f"fixture cache is being populated: {version}") from error

    temporary_root: Path | None = None
    archive_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=cache_root, delete=False) as handle:
            archive_path = Path(handle.name)
            with opener(str(lock["url"])) as response:
                shutil.copyfileobj(response, handle)
        if sha256_file(archive_path) != lock.get("sha256"):
            raise ValueError("fixture archive checksum mismatch")

        temporary_root = Path(tempfile.mkdtemp(prefix=f".{version}-", dir=cache_root))
        with tarfile.open(archive_path, "r:gz") as archive:
            members = archive.getmembers()
            names = [member.name for member in members]
            if any(
                not _safe_member(member.name)
                or not member.isfile()
                or member.issym()
                or member.islnk()
                for member in members
            ):
                raise ValueError("fixture archive contains unsafe member")
            if "manifest.json" not in names:
                raise ValueError("fixture archive has no manifest.json")
            manifest_member = archive.extractfile("manifest.json")
            if manifest_member is None:
                raise ValueError("fixture archive has no manifest.json")
            manifest_bytes = manifest_member.read()
            manifest_path = temporary_root / "manifest.json"
            manifest_path.write_bytes(manifest_bytes)
            manifest = load_manifest(manifest_path)
            expected = {
                "manifest.json",
                *EVIDENCE_MEMBERS,
                *(fixture["path"] for fixture in manifest.get("fixtures", [])),
            }
            if set(names) != expected or len(names) != len(expected):
                raise ValueError("fixture archive has missing, duplicate, or extra members")
            for member in members:
                if member.name == "manifest.json":
                    continue
                destination = temporary_root.joinpath(*PurePosixPath(member.name).parts)
                destination.parent.mkdir(parents=True, exist_ok=True)
                source = archive.extractfile(member)
                if source is None:
                    raise ValueError(f"fixture member cannot be read: {member.name}")
                with destination.open("wb") as output:
                    shutil.copyfileobj(source, output)
        _verify_root(temporary_root, lock)
        os.replace(temporary_root, target)
        temporary_root = None
        return target
    finally:
        if archive_path is not None:
            archive_path.unlink(missing_ok=True)
        if temporary_root is not None:
            shutil.rmtree(temporary_root, ignore_errors=True)
        lock_directory.rmdir()


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, default=Path("upstreams/fixture-pack.lock.json"))
    parser.add_argument("--cache", type=Path, default=Path(".perfetto-fixtures"))
    args = parser.parse_args(arguments)
    print(download_pack(args.lock, args.cache))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

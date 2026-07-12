#!/usr/bin/env python3
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SKILL_NAME = "perfetto-performance-analysis"
SKILL_ROOT = ROOT / "skills" / SKILL_NAME
VERSION_PATTERN = re.compile(r"^[0-9A-Za-z][0-9A-Za-z._-]*$")
EXCLUDED_PARTS = {"__pycache__", ".DS_Store", ".perfetto-cache"}
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def skill_metadata_version(path: Path = SKILL_ROOT / "SKILL.md") -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    in_metadata = False
    for line in lines:
        if line == "metadata:":
            in_metadata = True
            continue
        if in_metadata and line and not line.startswith((" ", "\t")):
            break
        if in_metadata:
            match = re.match(r"\s+version:\s*[\"']?([^\"'\s]+)", line)
            if match:
                return match.group(1)
    raise ValueError(f"Skill metadata version is missing: {path}")


def release_entries(version: str) -> list[tuple[str, bytes, int]]:
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"invalid release version: {version!r}")
    declared_version = skill_metadata_version(SKILL_ROOT / "SKILL.md")
    if version != declared_version:
        raise ValueError(
            f"release version {version} does not match Skill metadata version {declared_version}"
        )
    catalog_path = ROOT / "catalog" / "smartperfetto-export.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    entries: list[tuple[str, bytes, int]] = []
    for path in sorted(SKILL_ROOT.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"release must not follow a symbolic link: {path}")
        if not path.is_file() or any(part in EXCLUDED_PARTS for part in path.parts):
            continue
        relative = path.relative_to(SKILL_ROOT).as_posix()
        archive_name = f"{SKILL_NAME}/{relative}"
        if path.name in {"trace_processor_shell", "trace_processor_shell.exe"}:
            raise ValueError(f"release must not bundle an executable: {path}")
        mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
        entries.append((archive_name, path.read_bytes(), mode))
    provenance = {
        "schema_version": 1,
        "name": SKILL_NAME,
        "version": version,
        "source": catalog["source"],
        "catalog_sha256": sha256_bytes(catalog_path.read_bytes()),
    }
    entries.extend(
        [
            ("tools/install.py", (ROOT / "tools" / "install.py").read_bytes(), 0o755),
            ("LICENSE", (ROOT / "LICENSE").read_bytes(), 0o644),
            ("NOTICE", (ROOT / "NOTICE").read_bytes(), 0o644),
            (
                "PROVENANCE.json",
                (
                    json.dumps(provenance, ensure_ascii=False, indent=2, sort_keys=True)
                    + "\n"
                ).encode("utf-8"),
                0o644,
            ),
        ]
    )
    return sorted(entries, key=lambda item: item[0])


def write_zip(path: Path, entries: list[tuple[str, bytes, int]]) -> None:
    with zipfile.ZipFile(
        path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for name, content, mode in entries:
            info = zipfile.ZipInfo(name, FIXED_ZIP_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = (mode & 0xFFFF) << 16
            info.flag_bits |= 0x800
            archive.writestr(info, content, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def write_tar_gz(path: Path, entries: list[tuple[str, bytes, int]]) -> None:
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with tarfile.open(
                fileobj=compressed,
                mode="w",
                format=tarfile.GNU_FORMAT,
            ) as archive:
                for name, content, mode in entries:
                    info = tarfile.TarInfo(name)
                    info.size = len(content)
                    info.mode = mode
                    info.mtime = 0
                    info.uid = 0
                    info.gid = 0
                    info.uname = ""
                    info.gname = ""
                    archive.addfile(info, io.BytesIO(content))


def build_release(output: Path, version: str) -> tuple[Path, Path, Path]:
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"invalid release version: {version!r}")
    output = output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    entries = release_entries(version)
    stem = f"perfetto-skills-{version}"
    zip_path = output / f"{stem}.zip"
    tar_path = output / f"{stem}.tar.gz"
    checksums = output / "SHA256SUMS"
    write_zip(zip_path, entries)
    write_tar_gz(tar_path, entries)
    checksum_text = "".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
        for path in (tar_path, zip_path)
    )
    checksums.write_text(checksum_text, encoding="utf-8")
    return zip_path, tar_path, checksums


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build reproducible Skill release archives.")
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args(argv)
    for path in build_release(args.output, args.version):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from io import BytesIO
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

from tools.build_fixture_pack import build_pack
from tools.download_fixture_pack import download_pack
from tools.fixture_manifest import sha256_file


def write_manifest(root: Path, payload: bytes = b"real trace") -> Path:
    trace = root / "traces" / "sample.pftrace"
    trace.parent.mkdir(parents=True)
    trace.write_bytes(payload)
    manifest = {
        "schema_version": 1,
        "fixture_pack_version": "fixtures-test",
        "fixtures": [
            {
                "id": "sample",
                "path": "traces/sample.pftrace",
                "sha256": sha256_file(trace),
                "license": "Apache-2.0",
                "origin": {
                    "repository": "https://github.com/google/perfetto",
                    "commit": "a" * 40,
                    "path": "test/data/sample.pftrace",
                    "redistribution_review": "approved",
                },
                "real": True,
                "privacy_review": {"status": "passed"},
                "capture": {"config": "test"},
                "platform": {"api": 32},
                "capabilities": ["startup"],
                "assertions": [],
            }
        ],
    }
    path = root / "manifest.json"
    path.write_text(json.dumps(manifest, sort_keys=True), encoding="utf-8")
    return path


class FixturePackTest(unittest.TestCase):
    def test_build_is_reproducible_and_metadata_is_normalized(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = write_manifest(root)
            first = build_pack(manifest, root, root / "first.tar.gz")
            second = build_pack(manifest, root, root / "second.tar.gz")
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with tarfile.open(first, "r:gz") as archive:
                members = archive.getmembers()
            self.assertEqual([member.name for member in members], sorted(member.name for member in members))
            for member in members:
                self.assertEqual(member.mtime, 0)
                self.assertEqual((member.uid, member.gid), (0, 0))
                self.assertEqual((member.uname, member.gname), ("", ""))
                self.assertEqual(member.mode, 0o644)

    def test_download_verifies_archive_and_every_member(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = write_manifest(root)
            archive = build_pack(manifest, root, root / "fixtures.tar.gz")
            lock = root / "lock.json"
            lock.write_text(
                json.dumps(
                    {
                        "version": "fixtures-test",
                        "url": "https://example.invalid/fixtures.tar.gz",
                        "sha256": sha256_file(archive),
                        "manifest_sha256": sha256_file(manifest),
                    }
                ),
                encoding="utf-8",
            )
            resolved = download_pack(
                lock,
                root / "cache",
                opener=lambda _: BytesIO(archive.read_bytes()),
            )
            self.assertEqual((resolved / "traces/sample.pftrace").read_bytes(), b"real trace")
            self.assertEqual(download_pack(lock, root / "cache"), resolved)

    def test_download_rejects_extra_or_unsafe_archive_members(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = write_manifest(root)
            for member_name in ("unexpected.txt", "../escaped.txt"):
                with self.subTest(member=member_name):
                    archive = root / f"{member_name.replace('/', '_')}.tar.gz"
                    with tarfile.open(archive, "w:gz") as handle:
                        info = tarfile.TarInfo(member_name)
                        info.size = 1
                        handle.addfile(info, BytesIO(b"x"))
                    lock = root / "lock.json"
                    lock.write_text(
                        json.dumps(
                            {
                                "version": "fixtures-test",
                                "url": "https://example.invalid/fixtures.tar.gz",
                                "sha256": sha256_file(archive),
                                "manifest_sha256": sha256_file(manifest),
                            }
                        ),
                        encoding="utf-8",
                    )
                    with self.assertRaises(ValueError):
                        download_pack(
                            lock,
                            root / f"cache-{member_name.replace('/', '_')}",
                            opener=lambda _, archive=archive: BytesIO(archive.read_bytes()),
                        )


if __name__ == "__main__":
    unittest.main()

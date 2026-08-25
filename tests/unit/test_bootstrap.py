from pathlib import Path
import hashlib
import io
import json
import tempfile
import unittest

from tests.support import SCRIPTS, load_skill_script


class BootstrapTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue(
            (SCRIPTS / "bootstrap_trace_processor.py").is_file(),
            "scripts/bootstrap_trace_processor.py",
        )
        self.bootstrap = load_skill_script("bootstrap_trace_processor")

    def test_platform_mapping_is_explicit(self) -> None:
        self.assertEqual(self.bootstrap.platform_key("Darwin", "arm64"), "mac-arm64")
        self.assertEqual(
            self.bootstrap.platform_key("Linux", "x86_64"), "linux-amd64"
        )
        self.assertEqual(
            self.bootstrap.platform_key("Windows", "AMD64"), "windows-amd64"
        )
        with self.assertRaisesRegex(RuntimeError, "Unsupported platform"):
            self.bootstrap.platform_key("Plan9", "mips")

    def test_hash_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "download"
            path.write_bytes(b"wrong")
            expected = hashlib.sha256(b"right").hexdigest()
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                self.bootstrap.verify_sha256(path, expected)

    def test_locked_download_is_verified_and_installed(self) -> None:
        payload = b"verified executable"
        expected = hashlib.sha256(payload).hexdigest()
        lock = {
            "revision": "a" * 40,
            "reported_version": "v57.2",
            "rpc_api_version": 14,
            "base_url": "https://example.invalid",
            "platforms": {
                "mac-arm64": {
                    "path": f"{'a' * 40}/mac-arm64/trace_processor_shell",
                    "sha256": expected,
                }
            },
        }

        with tempfile.TemporaryDirectory() as tmp:
            installed = self.bootstrap.install_locked_binary(
                lock,
                "mac-arm64",
                Path(tmp),
                opener=lambda _: io.BytesIO(payload),
            )
            self.assertEqual(installed.read_bytes(), payload)
            self.assertTrue(installed.stat().st_mode & 0o100)
            self.assertIn("a" * 40, installed.parts)

    def test_release_artifact_path_stays_separate_from_revision_cache_key(self) -> None:
        payload = b"verified executable"
        expected = hashlib.sha256(payload).hexdigest()
        revision = "a" * 40
        lock = {
            "schema_version": 2,
            "revision": revision,
            "artifact_version": "v58.2",
            "reported_version": "v58.2",
            "rpc_api_version": 14,
            "base_url": "https://example.invalid",
            "source": "test",
            "platforms": {
                "mac-arm64": {
                    "path": "v58.2/mac-arm64/trace_processor_shell",
                    "sha256": expected,
                }
            },
        }
        urls: list[str] = []

        def open_artifact(url: str) -> io.BytesIO:
            urls.append(url)
            return io.BytesIO(payload)

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "lock.json"
            path.write_text(json.dumps(lock), encoding="utf-8")
            loaded = self.bootstrap.load_lock(path)
            installed = self.bootstrap.install_locked_binary(
                loaded,
                "mac-arm64",
                Path(tmp) / "cache",
                opener=open_artifact,
            )

            self.assertEqual(
                urls,
                ["https://example.invalid/v58.2/mac-arm64/trace_processor_shell"],
            )
            self.assertIn(revision, installed.parts)
            self.assertNotIn("v58.2", installed.parts)

    def test_load_lock_rejects_paths_outside_the_revision_platform(self) -> None:
        valid = {
            "schema_version": 2,
            "revision": "a" * 40,
            "reported_version": "v57.2",
            "rpc_api_version": 14,
            "base_url": "https://example.invalid",
            "source": "test",
            "platforms": {
                "mac-arm64": {
                    "path": f"{'a' * 40}/mac-arm64/trace_processor_shell",
                    "sha256": "b" * 64,
                }
            },
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "lock.json"
            for forged in (
                "../trace_processor_shell",
                f"{'c' * 40}/mac-arm64/trace_processor_shell",
                f"{'a' * 40}/linux-amd64/trace_processor_shell",
                f"{'a' * 40}/mac-arm64/trace_processor_shell.exe",
            ):
                with self.subTest(path=forged):
                    document = json.loads(json.dumps(valid))
                    document["platforms"]["mac-arm64"]["path"] = forged
                    path.write_text(json.dumps(document), encoding="utf-8")
                    with self.assertRaises(ValueError):
                        self.bootstrap.load_lock(path)

    def test_revision_separates_binary_caches_with_same_reported_version(self) -> None:
        payload = b"verified executable"
        expected = hashlib.sha256(payload).hexdigest()
        with tempfile.TemporaryDirectory() as tmp:
            installed = []
            for revision in ("a" * 40, "b" * 40):
                lock = {
                    "revision": revision,
                    "reported_version": "v57.2",
                    "rpc_api_version": 14,
                    "base_url": "https://example.invalid",
                    "platforms": {
                        "mac-arm64": {
                            "path": f"{revision}/mac-arm64/trace_processor_shell",
                            "sha256": expected,
                        }
                    },
                }
                installed.append(
                    self.bootstrap.install_locked_binary(
                        lock,
                        "mac-arm64",
                        Path(tmp),
                        opener=lambda _: io.BytesIO(payload),
                    )
                )
            self.assertNotEqual(installed[0], installed[1])

    def test_committed_lock_covers_supported_platforms(self) -> None:
        lock_path = (
            SCRIPTS.parent / "references" / "trace-processor-lock.json"
        )
        self.assertTrue(lock_path.is_file(), "references/trace-processor-lock.json")
        lock = json.loads(lock_path.read_text(encoding="utf-8"))
        self.assertEqual(
            lock["revision"],
            "add693d8b338ba9599dbcbc3e300b1ab8c000897",
        )
        self.assertEqual(lock["schema_version"], 2)
        self.assertEqual(lock["artifact_version"], "v58.2")
        self.assertEqual(lock["reported_version"], "v58.2")
        self.assertEqual(lock["rpc_api_version"], 14)
        self.assertEqual(
            set(lock["platforms"]),
            {
                "linux-amd64",
                "linux-arm64",
                "mac-amd64",
                "mac-arm64",
                "windows-amd64",
            },
        )


if __name__ == "__main__":
    unittest.main()

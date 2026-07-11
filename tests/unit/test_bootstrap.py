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
            "perfetto_version": "v-test",
            "base_url": "https://example.invalid",
            "platforms": {
                "mac-arm64": {
                    "path": "v-test/mac-arm64/trace_processor_shell",
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

    def test_committed_lock_covers_supported_platforms(self) -> None:
        lock_path = (
            SCRIPTS.parent / "references" / "trace-processor-lock.json"
        )
        self.assertTrue(lock_path.is_file(), "references/trace-processor-lock.json")
        lock = json.loads(lock_path.read_text(encoding="utf-8"))
        self.assertEqual(lock["perfetto_version"], "v57.1")
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

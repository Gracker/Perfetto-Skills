from pathlib import Path
import tempfile
import unittest

from tools.scan_fixture_privacy import RULESET_VERSION, scan_file


class FixturePrivacyScannerTest(unittest.TestCase):
    def test_detects_high_risk_printable_strings(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            trace = Path(temporary) / "trace.pftrace"
            trace.write_bytes(
                b"binary\x00alice@example.com\x00Bearer secret-token\x00/Users/alice/project"
            )
            result = scan_file(trace)
            self.assertEqual(result["ruleset"], RULESET_VERSION)
            self.assertEqual(
                {finding["rule"] for finding in result["findings"]},
                {"email", "bearer_token", "private_home_path"},
            )
            self.assertFalse(result["passed"])

    def test_reports_hash_and_passes_benign_trace(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            trace = Path(temporary) / "trace.pftrace"
            trace.write_bytes(b"perfetto\x00com.example.fixture\x00RenderThread")
            result = scan_file(trace)
            self.assertTrue(result["passed"])
            self.assertRegex(result["sha256"], r"^[0-9a-f]{64}$")


if __name__ == "__main__":
    unittest.main()

from pathlib import Path
import tempfile
import unittest

from tests.support import fixture_path


ROOT = Path(__file__).resolve().parents[2]


class FixtureLookupTest(unittest.TestCase):
    def test_resolves_and_verifies_committed_smoke_fixture(self) -> None:
        trace = fixture_path("startup-api32-warm-smoke", root=ROOT / "fixtures")
        self.assertEqual(trace.name, "api32_startup_warm.perfetto-trace")

    def test_rejects_unknown_fixture(self) -> None:
        with self.assertRaises(KeyError):
            fixture_path("does-not-exist", root=ROOT / "fixtures")

    def test_rejects_hash_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "smoke" / "api32_startup_warm.perfetto-trace"
            target.parent.mkdir(parents=True)
            target.write_bytes(b"tampered")
            with self.assertRaises(ValueError):
                fixture_path("startup-api32-warm-smoke", root=root)


if __name__ == "__main__":
    unittest.main()

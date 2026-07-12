import json
from pathlib import Path
import tempfile
import unittest

from tools.fixture_manifest import load_manifest, sha256_file, validate_manifest


ROOT = Path(__file__).resolve().parents[2]


def valid_fixture(**updates: object) -> dict[str, object]:
    fixture: dict[str, object] = {
        "id": "fixture-a",
        "path": "traces/fixture-a.pftrace",
        "sha256": "a" * 64,
        "license": "Apache-2.0",
        "origin": {
            "repository": "https://github.com/google/perfetto",
            "commit": "b" * 40,
            "path": "test/data/fixture-a.pftrace",
            "redistribution_review": "approved",
        },
        "real": True,
        "privacy_review": {"status": "passed", "reviewed_at": "2026-07-12"},
        "capture": {"config": "embedded_in_trace"},
        "platform": {"api": 32, "oem": "AOSP", "kernel": "unknown"},
        "capabilities": ["android_startup"],
        "assertions": [{"id": "startup-warm", "query_id": "startup/overview"}],
    }
    fixture.update(updates)
    return fixture


class OwnedFixtureManifestTest(unittest.TestCase):
    def test_committed_manifest_is_valid(self) -> None:
        manifest = load_manifest(ROOT / "fixtures/manifest.json")
        self.assertEqual(validate_manifest(manifest), [])
        self.assertGreaterEqual(len(manifest["fixtures"]), 11)

    def test_rejects_duplicate_ids_paths_and_unsafe_paths(self) -> None:
        duplicate = valid_fixture(id="fixture-b")
        manifest = {
            "schema_version": 1,
            "fixture_pack_version": "fixtures-v1",
            "fixtures": [valid_fixture(), duplicate],
        }
        issues = validate_manifest(manifest)
        self.assertTrue(any("duplicate path" in issue for issue in issues), issues)
        manifest["fixtures"][1] = valid_fixture(
            id="fixture-a", path="../escaped.pftrace"
        )
        issues = validate_manifest(manifest)
        self.assertTrue(any("duplicate id" in issue for issue in issues), issues)
        self.assertTrue(any("unsafe path" in issue for issue in issues), issues)

    def test_rejects_invalid_hash_or_unreviewed_real_fixture(self) -> None:
        manifest = {
            "schema_version": 1,
            "fixture_pack_version": "fixtures-v1",
            "fixtures": [
                valid_fixture(
                    sha256="not-a-hash",
                    real=False,
                    privacy_review={"status": "pending"},
                    origin={
                        "repository": "https://github.com/google/perfetto",
                        "commit": "b" * 40,
                        "path": "fixture.pftrace",
                        "redistribution_review": "pending",
                    },
                )
            ],
        }
        issues = validate_manifest(manifest)
        for fragment in (
            "invalid sha256",
            "release-blocking assertions require real trace",
            "privacy review must pass",
            "redistribution review must be approved",
        ):
            self.assertTrue(any(fragment in issue for issue in issues), issues)

    def test_sha256_file_and_load_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.json"
            path.write_text(json.dumps({"fixtures": []}), encoding="utf-8")
            self.assertEqual(load_manifest(path), {"fixtures": []})
            self.assertEqual(
                sha256_file(path),
                "e80e9a3236626c293b1bb7d10e31e7b6acd2e9f4b6c9db27d34b5bc2fc9c8b18",
            )


if __name__ == "__main__":
    unittest.main()

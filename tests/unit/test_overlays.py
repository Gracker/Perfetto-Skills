import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.overlays import load_overlays


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


class OverlayValidationTest(unittest.TestCase):
    def test_loads_complete_sql_overlay(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            replacement = root / "replacement.sql"
            replacement.write_text("SELECT 2;", encoding="utf-8")
            descriptor = {
                "schema_version": 1,
                "target": "sql/example/query.sql",
                "kind": "sql",
                "expected_base_sha256": digest(b"SELECT 1;"),
                "replacement": "replacement.sql",
                "replacement_sha256": digest(b"SELECT 2;"),
                "reason": "fix regression",
                "regression_ids": ["assertion-1"],
                "base_failure_signature": "rows[0].value was 1",
                "upstream_candidate": "propose",
            }
            (root / "query.overlay.json").write_text(
                json.dumps(descriptor), encoding="utf-8"
            )
            overlays = load_overlays(root)
            self.assertEqual(len(overlays), 1)
            self.assertEqual(overlays[0].target, descriptor["target"])

    def test_rejects_unsafe_duplicate_or_incomplete_overlays(self) -> None:
        cases = (
            ("../escape.sql", "unsafe target"),
            ("sql/a.sql", "replacement hash mismatch"),
        )
        for target, expected in cases:
            with self.subTest(target=target), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                (root / "replacement.sql").write_text("SELECT 2;", encoding="utf-8")
                descriptor = {
                    "schema_version": 1,
                    "target": target,
                    "kind": "sql",
                    "expected_base_sha256": digest(b"SELECT 1;"),
                    "replacement": "replacement.sql",
                    "replacement_sha256": "0" * 64,
                    "reason": "fix",
                    "regression_ids": [],
                    "base_failure_signature": "",
                    "upstream_candidate": "invalid",
                }
                (root / "query.overlay.json").write_text(
                    json.dumps(descriptor), encoding="utf-8"
                )
                with self.assertRaisesRegex(ValueError, expected):
                    load_overlays(root)

    def test_rejects_replacement_outside_overlay_and_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            root = parent / "overrides"
            root.mkdir()
            outside = parent / "outside.sql"
            outside.write_text("SELECT 2;", encoding="utf-8")
            descriptor = {
                "schema_version": 1,
                "target": "sql/example/query.sql",
                "kind": "sql",
                "expected_base_sha256": digest(b"SELECT 1;"),
                "replacement": "../outside.sql",
                "replacement_sha256": digest(outside.read_bytes()),
                "reason": "fix",
                "regression_ids": ["assertion-1"],
                "base_failure_signature": "old row",
                "upstream_candidate": "local_only",
            }
            (root / "query.overlay.json").write_text(
                json.dumps(descriptor), encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "missing replacement"):
                load_overlays(root)
            descriptor["replacement"] = "linked.sql"
            (root / "linked.sql").symlink_to(outside)
            (root / "query.overlay.json").write_text(
                json.dumps(descriptor), encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "missing replacement"):
                load_overlays(root)
            outside_directory = parent / "outside"
            outside_directory.mkdir()
            (outside_directory / "nested.sql").write_text(
                "SELECT 2;", encoding="utf-8"
            )
            (root / "linked-directory").symlink_to(
                outside_directory, target_is_directory=True
            )
            descriptor["replacement"] = "linked-directory/nested.sql"
            (root / "query.overlay.json").write_text(
                json.dumps(descriptor), encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "missing replacement"):
                load_overlays(root)


if __name__ == "__main__":
    unittest.main()

from pathlib import Path
import json
import subprocess
import tempfile
import unittest
from unittest import mock

from tools import sync_smartperfetto
from tools.sync_smartperfetto import apply_import, compare_import, validate_source


class SmartPerfettoSyncTest(unittest.TestCase):
    def test_compare_import_reports_added_removed_and_changed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base = root / "base"
            imported = root / "imported"
            base.mkdir()
            imported.mkdir()
            (base / "same").write_text("same", encoding="utf-8")
            (imported / "same").write_text("same", encoding="utf-8")
            (base / "changed").write_text("before", encoding="utf-8")
            (imported / "changed").write_text("after", encoding="utf-8")
            (base / "removed").write_text("removed", encoding="utf-8")
            (imported / "added").write_text("added", encoding="utf-8")
            self.assertEqual(
                compare_import(base, imported),
                {
                    "added": ["added"],
                    "removed": ["removed"],
                    "changed": ["changed"],
                    "unchanged": 1,
                },
            )

    def test_source_validation_rejects_wrong_repository_or_commit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            subprocess.run(["git", "init", "-q", root], check=True)
            subprocess.run(
                ["git", "-C", root, "config", "user.email", "test@example.com"],
                check=True,
            )
            subprocess.run(
                ["git", "-C", root, "config", "user.name", "Test"], check=True
            )
            (root / "file").write_text("data", encoding="utf-8")
            subprocess.run(["git", "-C", root, "add", "file"], check=True)
            subprocess.run(["git", "-C", root, "commit", "-qm", "test"], check=True)
            subprocess.run(
                ["git", "-C", root, "remote", "add", "origin", "https://github.com/example/wrong"],
                check=True,
            )
            with self.assertRaisesRegex(ValueError, "identity"):
                validate_source(root, "https://github.com/Gracker/SmartPerfetto", "a" * 40)

    def test_apply_rolls_back_base_lock_and_outputs_after_late_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            upstreams = root / "upstreams"
            base = upstreams / "base"
            base.mkdir(parents=True)
            (base / "value").write_text("old", encoding="utf-8")
            manifest = upstreams / "base-manifest.json"
            manifest.write_text("old manifest", encoding="utf-8")
            lock_path = upstreams / "smartperfetto.lock.json"
            lock = {
                "commit": "a" * 40,
                "generated_base_root": "base",
                "generated_base_manifest": "base-manifest.json",
                "policy_sha256": "b" * 64,
            }
            lock_path.write_text("old lock", encoding="utf-8")
            catalog = root / "catalog/smartperfetto-export.json"
            migration = root / "docs/migration-coverage.md"
            catalog.parent.mkdir()
            migration.parent.mkdir()
            catalog.write_text("old catalog", encoding="utf-8")
            migration.write_text("old migration", encoding="utf-8")
            imported_root = root / "imported"
            generated = imported_root / "generated"
            generated.mkdir(parents=True)
            (generated / "value").write_text("new", encoding="utf-8")
            imported_catalog = imported_root / "catalog.json"
            imported_catalog.write_text(
                '{"source":{"policy_sha256":"' + "c" * 64 + '"}}',
                encoding="utf-8",
            )
            imported_migration = imported_root / "migration.md"
            imported_migration.write_text("new migration", encoding="utf-8")
            imported = {
                "generated": generated,
                "catalog": imported_catalog,
                "migration": imported_migration,
            }
            with (
                mock.patch.object(sync_smartperfetto, "ROOT", root),
                mock.patch.object(
                    sync_smartperfetto,
                    "write_generated_base_manifest",
                    side_effect=RuntimeError("late failure"),
                ),
                self.assertRaisesRegex(RuntimeError, "late failure"),
            ):
                apply_import(imported, lock_path, lock, "d" * 40)
            self.assertEqual((base / "value").read_text(encoding="utf-8"), "old")
            self.assertEqual(lock_path.read_text(encoding="utf-8"), "old lock")
            self.assertEqual(manifest.read_text(encoding="utf-8"), "old manifest")
            self.assertEqual(catalog.read_text(encoding="utf-8"), "old catalog")
            self.assertEqual(migration.read_text(encoding="utf-8"), "old migration")

    def test_replace_tree_swaps_content_and_cleans_temporary_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            target.mkdir()
            (source / "value").write_text("new", encoding="utf-8")
            (target / "value").write_text("old", encoding="utf-8")
            sync_smartperfetto._replace_tree(source, target)
            self.assertEqual((target / "value").read_text(encoding="utf-8"), "new")
            self.assertFalse((root / ".target.next").exists())
            self.assertFalse((root / ".target.previous").exists())

    def test_apply_import_commits_all_outputs_consistently(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            upstreams = root / "upstreams"
            base = upstreams / "base"
            base.mkdir(parents=True)
            (base / "value").write_text("old", encoding="utf-8")
            lock_path = upstreams / "smartperfetto.lock.json"
            lock = {
                "commit": "a" * 40,
                "generated_base_root": "base",
                "generated_base_manifest": "base-manifest.json",
                "policy_sha256": "b" * 64,
            }
            lock_path.write_text(json.dumps(lock), encoding="utf-8")
            (root / "catalog").mkdir()
            (root / "docs").mkdir()
            imported_root = root / "imported"
            generated = imported_root / "generated"
            generated.mkdir(parents=True)
            (generated / "value").write_text("new", encoding="utf-8")
            imported_catalog = imported_root / "catalog.json"
            imported_catalog.write_text(
                '{"source":{"policy_sha256":"' + "c" * 64 + '"}}',
                encoding="utf-8",
            )
            imported_migration = imported_root / "migration.md"
            imported_migration.write_text("new migration", encoding="utf-8")
            with mock.patch.object(sync_smartperfetto, "ROOT", root):
                apply_import(
                    {
                        "generated": generated,
                        "catalog": imported_catalog,
                        "migration": imported_migration,
                    },
                    lock_path,
                    lock,
                    "d" * 40,
                )
            self.assertEqual((base / "value").read_text(encoding="utf-8"), "new")
            persisted_lock = json.loads(lock_path.read_text(encoding="utf-8"))
            self.assertEqual(persisted_lock["commit"], "d" * 40)
            persisted_manifest = json.loads(
                (upstreams / "base-manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(persisted_manifest["source_commit"], "d" * 40)
            self.assertEqual(
                (root / "catalog/smartperfetto-export.json").read_text(encoding="utf-8"),
                imported_catalog.read_text(encoding="utf-8"),
            )
            self.assertEqual(
                (root / "docs/migration-coverage.md").read_text(encoding="utf-8"),
                "new migration",
            )


if __name__ == "__main__":
    unittest.main()

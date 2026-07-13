from pathlib import Path
import json
import subprocess
import tempfile
import unittest
from unittest import mock

from tools import sync_smartperfetto
from tools.sync_smartperfetto import (
    apply_import,
    compare_import,
    compare_import_contract,
    import_is_current,
    validate_source,
)


class SmartPerfettoSyncTest(unittest.TestCase):
    def test_import_is_current_only_when_no_paths_drift(self) -> None:
        current = {
            "added": [],
            "removed": [],
            "changed": [],
            "unchanged": 3,
        }
        self.assertTrue(import_is_current(current))
        for key in ("added", "removed", "changed"):
            with self.subTest(key=key):
                drift = {**current, key: ["path"]}
                self.assertFalse(import_is_current(drift))

    def test_import_contract_detects_catalog_migration_and_policy_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base = root / "base"
            imported_root = root / "imported"
            imported_generated = imported_root / "generated"
            base.mkdir()
            imported_generated.mkdir(parents=True)
            (base / "same").write_text("same", encoding="utf-8")
            (imported_generated / "same").write_text("same", encoding="utf-8")
            catalog = root / "catalog.json"
            imported_catalog = imported_root / "catalog.json"
            catalog_payload = '{"source":{"policy_sha256":"' + "a" * 64 + '"}}\n'
            catalog.write_text(catalog_payload, encoding="utf-8")
            imported_catalog.write_text(catalog_payload, encoding="utf-8")
            migration = root / "migration.md"
            imported_migration = imported_root / "migration.md"
            migration.write_text("current\n", encoding="utf-8")
            imported_migration.write_text("current\n", encoding="utf-8")
            imported = {
                "generated": imported_generated,
                "catalog": imported_catalog,
                "migration": imported_migration,
            }

            def compare() -> dict[str, object]:
                return compare_import_contract(
                    base,
                    imported,
                    catalog_target=catalog,
                    migration_target=migration,
                    policy_sha256="a" * 64,
                )

            self.assertTrue(import_is_current(compare()))
            for path, payload, key in (
                (imported_catalog, '{"source":{"policy_sha256":"' + "b" * 64 + '"}}\n', "catalog_changed"),
                (imported_migration, "changed\n", "migration_changed"),
            ):
                with self.subTest(key=key):
                    original = path.read_text(encoding="utf-8")
                    path.write_text(payload, encoding="utf-8")
                    self.assertTrue(compare()[key])
                    self.assertFalse(import_is_current(compare()))
                    path.write_text(original, encoding="utf-8")
            self.assertTrue(
                compare_import_contract(
                    base,
                    imported,
                    catalog_target=catalog,
                    migration_target=migration,
                    policy_sha256="b" * 64,
                )["policy_sha256_changed"]
            )

    def test_check_mode_returns_two_when_import_contract_drifts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lock = root / "smartperfetto.lock.json"
            lock.write_text(
                json.dumps(
                    {
                        "commit": "a" * 40,
                        "repository": "https://github.com/Gracker/SmartPerfetto",
                        "generated_base_root": "base",
                        "policy_sha256": "b" * 64,
                    }
                ),
                encoding="utf-8",
            )
            imported = {
                "generated": root / "imported/generated",
                "catalog": root / "imported/catalog.json",
                "migration": root / "imported/migration.md",
            }
            with (
                mock.patch.object(sync_smartperfetto, "ROOT", root),
                mock.patch.object(sync_smartperfetto, "validate_source"),
                mock.patch.object(sync_smartperfetto, "import_to_directory", return_value=imported),
                mock.patch.object(
                    sync_smartperfetto,
                    "compare_import_contract",
                    return_value={
                        "added": ["new"],
                        "removed": [],
                        "changed": [],
                        "unchanged": 0,
                        "catalog_changed": False,
                        "migration_changed": False,
                        "policy_sha256_changed": False,
                    },
                ),
            ):
                result = sync_smartperfetto.main(
                    [
                        "--source",
                        str(root / "source"),
                        "--lock",
                        str(lock),
                        "--report-dir",
                        str(root / "reports"),
                        "--check",
                    ]
                )
            self.assertEqual(result, 2)

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

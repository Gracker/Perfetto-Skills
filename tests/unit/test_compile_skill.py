import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.compile_skill import _apply_native_assets, compile_tree


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


class CompileSkillTest(unittest.TestCase):
    def test_native_skill_manifest_updates_runtime_index(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            compiled = root / "compiled"
            index = compiled / "runtime/skill-index.json"
            index.parent.mkdir(parents=True)
            index.write_text(
                json.dumps({"schema_version": 1, "skills": {}}), encoding="utf-8"
            )
            src = root / "src"
            skill = src / "skills/local.json"
            skill.parent.mkdir(parents=True)
            skill.write_text(json.dumps({"id": "local"}), encoding="utf-8")
            manifest = src / "native-manifest.json"
            manifest.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "assets": [
                            {
                                "kind": "skill",
                                "source": "skills/local.json",
                                "target": "runtime/skills/local.json",
                                "sha256": digest(skill.read_bytes()),
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            _apply_native_assets(compiled, manifest)
            runtime_index = json.loads(index.read_text(encoding="utf-8"))
            self.assertEqual(runtime_index["skills"]["local"], "skills/local.json")

    def test_native_manifest_rejects_symlink_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            compiled = root / "compiled"
            compiled.mkdir()
            src = root / "src"
            skill = src / "skills/local.json"
            skill.parent.mkdir(parents=True)
            outside = root / "outside.json"
            outside.write_text(json.dumps({"id": "local"}), encoding="utf-8")
            skill.symlink_to(outside)
            manifest = src / "native-manifest.json"
            manifest.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "assets": [
                            {
                                "kind": "skill",
                                "source": "skills/local.json",
                                "target": "runtime/skills/local.json",
                                "sha256": digest(outside.read_bytes()),
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "native asset hash mismatch"):
                _apply_native_assets(compiled, manifest)
            skill.unlink()
            linked_directory = src / "linked-directory"
            linked_directory.symlink_to(root, target_is_directory=True)
            manifest_payload = json.loads(manifest.read_text(encoding="utf-8"))
            manifest_payload["assets"][0]["source"] = "linked-directory/outside.json"
            manifest.write_text(json.dumps(manifest_payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "native asset hash mismatch"):
                _apply_native_assets(compiled, manifest)

    def test_applies_overlay_without_mutating_base_and_updates_query_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base = root / "base"
            sql = base / "sql/example/query.sql"
            sql.parent.mkdir(parents=True)
            sql.write_text("SELECT 1;", encoding="utf-8")
            shard = base / "runtime/queries/example.json"
            shard.parent.mkdir(parents=True)
            shard.write_text(
                json.dumps({"queries": [{"path": "sql/example/query.sql", "sha256": digest(b"SELECT 1;")}]}),
                encoding="utf-8",
            )
            overlays = root / "overrides"
            overlays.mkdir()
            replacement = overlays / "replacement.sql"
            replacement.write_text("SELECT 2;", encoding="utf-8")
            (overlays / "query.overlay.json").write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "target": "sql/example/query.sql",
                        "kind": "sql",
                        "expected_base_sha256": digest(b"SELECT 1;"),
                        "replacement": "replacement.sql",
                        "replacement_sha256": digest(b"SELECT 2;"),
                        "reason": "fix",
                        "regression_ids": ["assertion-1"],
                        "base_failure_signature": "old row",
                        "upstream_candidate": "local_only",
                    }
                ),
                encoding="utf-8",
            )
            output = root / "output"
            compile_tree(base, overlays, output)
            self.assertEqual(sql.read_text(encoding="utf-8"), "SELECT 1;")
            self.assertEqual((output / sql.relative_to(base)).read_text(encoding="utf-8"), "SELECT 2;")
            compiled_shard = json.loads((output / shard.relative_to(base)).read_text(encoding="utf-8"))
            self.assertEqual(compiled_shard["queries"][0]["sha256"], digest(b"SELECT 2;"))

    def test_stale_base_hash_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base = root / "base"
            target = base / "sql/example/query.sql"
            target.parent.mkdir(parents=True)
            target.write_text("upstream changed", encoding="utf-8")
            overlays = root / "overrides"
            overlays.mkdir()
            replacement = overlays / "replacement.sql"
            replacement.write_text("replacement", encoding="utf-8")
            (overlays / "query.overlay.json").write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "target": "sql/example/query.sql",
                        "kind": "sql",
                        "expected_base_sha256": digest(b"old upstream"),
                        "replacement": "replacement.sql",
                        "replacement_sha256": digest(b"replacement"),
                        "reason": "fix",
                        "regression_ids": ["assertion-1"],
                        "base_failure_signature": "old row",
                        "upstream_candidate": "local_only",
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "stale overlay"):
                compile_tree(base, overlays, root / "output")

    def test_stale_dependent_base_hash_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base = root / "base"
            target = base / "runtime/skills/example.json"
            dependent = base / "runtime/skill-index.json"
            target.parent.mkdir(parents=True)
            target.write_text("base skill", encoding="utf-8")
            dependent.write_text("changed index", encoding="utf-8")
            overlays = root / "overrides"
            overlays.mkdir()
            replacement = overlays / "skill.json"
            replacement.write_text("local skill", encoding="utf-8")
            dependent_replacement = overlays / "index.json"
            dependent_replacement.write_text("local index", encoding="utf-8")
            (overlays / "skill.overlay.json").write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "target": "runtime/skills/example.json",
                        "kind": "skill",
                        "expected_base_sha256": digest(b"base skill"),
                        "replacement": "skill.json",
                        "replacement_sha256": digest(b"local skill"),
                        "reason": "local skill fix",
                        "regression_ids": [],
                        "upstream_candidate": "local_only",
                        "dependent_replacements": [
                            {
                                "target": "runtime/skill-index.json",
                                "expected_base_sha256": digest(b"old index"),
                                "replacement": "index.json",
                                "replacement_sha256": digest(b"local index"),
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "stale overlay dependent"):
                compile_tree(base, overlays, root / "output")


if __name__ == "__main__":
    unittest.main()

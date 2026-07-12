import json
from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"
GENERATED = SKILL / "references" / "generated"


class V02ContractTest(unittest.TestCase):
    def test_chinese_readme_explains_standard_and_install_boundary(self) -> None:
        readme = ROOT / "README.zh-CN.md"
        self.assertTrue(readme.is_file())
        text = readme.read_text(encoding="utf-8")
        self.assertIn("Agent Skills 规范", text)
        self.assertIn("不规定安装器", text)
        self.assertIn("npx skills@", text)
        self.assertIn("-a codex", text)
        self.assertIn("-a claude-code", text)
        self.assertIn("-a opencode", text)
        self.assertIn("README.md", text)

    def test_runtime_manifests_cover_every_exported_asset(self) -> None:
        runtime = GENERATED / "runtime"
        skill_index = json.loads(
            (runtime / "skill-index.json").read_text(encoding="utf-8")
        )
        sql_index = json.loads(
            (runtime / "sql-index.json").read_text(encoding="utf-8")
        )
        strategy_index = json.loads(
            (runtime / "strategy-index.json").read_text(encoding="utf-8")
        )
        self.assertEqual(skill_index["summary"]["skills"], 231)
        self.assertEqual(skill_index["summary"]["steps"], 746)
        self.assertEqual(skill_index["summary"]["step_conditions"], 246)
        self.assertEqual(len(skill_index["skills"]), 231)
        self.assertEqual(sql_index["summary"]["queries"], 643)
        self.assertEqual(strategy_index["summary"]["sources"], 65)
        self.assertEqual(len(strategy_index["strategies"]), 65)
        queries = []
        for shard in sql_index["shards"]:
            queries.extend(json.loads((runtime / shard).read_text(encoding="utf-8"))["queries"])
        self.assertEqual(len(queries), 643)
        for query in queries:
            self.assertEqual(len(query["compatibility"]["android"]), 10)
            self.assertRegex(query["sha256"], r"^[0-9a-f]{64}$")
            self.assertEqual(query["license"]["spdx"], "AGPL-3.0-or-later")
        gpu_frequency = next(
            query for query in queries if query["id"] == "gpu_metrics/gpu_frequency"
        )
        self.assertIn("gpu", gpu_frequency["compatibility"]["probe_capabilities"])
        validation = json.loads(
            (runtime / "sql-validation-report.json").read_text(encoding="utf-8")
        )
        self.assertEqual(validation["summary"]["static_valid"], 643)
        self.assertEqual(validation["summary"]["execution_verified"], 5)
        self.assertEqual(validation["summary"]["semantic_verified"], 5)
        self.assertEqual(validation["summary"]["capability_gated"], 638)

    def test_android_matrix_is_capability_first_for_api_28_through_37(self) -> None:
        runtime = GENERATED / "runtime"
        matrix = json.loads(
            (runtime / "android-index.json").read_text(encoding="utf-8")
        )
        self.assertEqual(matrix["api_levels"], list(range(28, 38)))
        self.assertEqual(
            set(matrix["capability_states"]),
            {
                "unsupported",
                "not_recorded",
                "recorded_empty",
                "recorded_populated",
                "unknown",
            },
        )
        self.assertEqual(len(matrix["skills"]), 231)
        for skill_id, relative in matrix["skills"].items():
            with self.subTest(skill=skill_id):
                entry = json.loads((runtime / relative).read_text(encoding="utf-8"))
                self.assertEqual(set(entry["api"]), {str(api) for api in range(28, 38)})
                self.assertEqual(entry["selection_order"][0], "device_capability")
                self.assertNotEqual(entry["api"]["37"]["status"], "verified")
        startup = json.loads(
            (runtime / matrix["skills"]["startup_slow_reasons"]).read_text(encoding="utf-8")
        )
        overview = startup["steps"]["startup_overview"]["api"]
        self.assertEqual(overview["31"]["status"], "verified")
        self.assertEqual(overview["32"]["status"], "verified")
        self.assertEqual(overview["34"]["status"], "verified")
        self.assertEqual(overview["36"]["status"], "verified")

    def test_fragments_overrides_source_lock_and_fixture_inventory_are_exported(self) -> None:
        runtime = GENERATED / "runtime"
        fragments = sorted((runtime / "fragments").glob("*.sql"))
        overrides = sorted((runtime / "vendor-overrides").glob("*.json"))
        self.assertEqual(len(fragments), 3)
        self.assertEqual(len(overrides), 8)
        self.assertTrue(all("advisory_only" in path.read_text() for path in overrides))

        source_lock = json.loads(
            (runtime / "perfetto-source-lock.json").read_text(encoding="utf-8")
        )
        self.assertEqual(source_lock["release"]["tag"], "v57.2")
        self.assertEqual(
            source_lock["release"]["commit"],
            "da1d152cff27890903d158fe96751de3aab883cc",
        )
        self.assertEqual(
            source_lock["release"]["stdlib_tree"],
            "7f0459ca3eed8372a8762ae052ed7fdb48eb3d88",
        )
        self.assertEqual(source_lock["official_skill_reference"]["role"], "gap_check_only")
        fixture_manifest = json.loads(
            (runtime / "fixture-manifest.json").read_text(encoding="utf-8")
        )
        self.assertIn("fixtures", fixture_manifest)

    def test_declared_modules_resolve_in_locked_official_index(self) -> None:
        runtime = GENERATED / "runtime"
        index = json.loads(
            (runtime / "skill-index.json").read_text(encoding="utf-8")
        )
        invalid = {
            "android.frames",
            "android.frames.jank",
            "linux.cpu.irq",
            "sched",
            "stack_profile",
        }
        declared = set()
        for relative in index["skills"].values():
            skill = json.loads((runtime / relative).read_text(encoding="utf-8"))
            declared.update(skill.get("prerequisites", {}).get("modules", []))
        self.assertFalse(declared & invalid)


if __name__ == "__main__":
    unittest.main()

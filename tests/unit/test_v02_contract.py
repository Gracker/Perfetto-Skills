import hashlib
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
        self.assertEqual(skill_index["summary"]["skills"], len(skill_index["skills"]))
        self.assertGreater(skill_index["summary"]["steps"], 0)
        self.assertGreaterEqual(
            skill_index["summary"]["steps"],
            skill_index["summary"]["step_conditions"],
        )
        self.assertEqual(sql_index["summary"]["shards"], len(sql_index["shards"]))
        self.assertEqual(
            strategy_index["summary"]["sources"],
            len(strategy_index["strategies"]),
        )
        queries = []
        for shard in sql_index["shards"]:
            queries.extend(json.loads((runtime / shard).read_text(encoding="utf-8"))["queries"])
        self.assertEqual(len(queries), sql_index["summary"]["queries"])
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
        self.assertEqual(validation["summary"]["queries"], len(queries))
        self.assertEqual(validation["summary"]["static_valid"], len(queries))
        self.assertEqual(
            validation["summary"]["capability_gated"]
            + validation["summary"]["semantic_verified"],
            len(queries),
        )

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
        skill_index = json.loads(
            (runtime / "skill-index.json").read_text(encoding="utf-8")
        )
        self.assertEqual(len(matrix["skills"]), skill_index["summary"]["skills"])
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
        catalog = json.loads(
            (ROOT / "catalog/smartperfetto-export.json").read_text(encoding="utf-8")
        )
        exported_fragments = [
            entry for entry in catalog["sql_fragments"]
            if entry["disposition"] == "exported"
        ]
        destinations = [entry["destination"] for entry in exported_fragments]
        self.assertEqual(len(destinations), len(set(destinations)))
        self.assertEqual(
            set(destinations),
            {path.relative_to(SKILL).as_posix() for path in fragments},
        )
        self.assertTrue(
            {
                "effective_target_processes.sql",
                "target_threads.sql",
                "thread_states_quadrant.sql",
                "vsync_config.sql",
            }.issubset({path.name for path in fragments})
        )
        lock = json.loads(
            (ROOT / "upstreams/smartperfetto.lock.json").read_text(encoding="utf-8")
        )
        manifest = json.loads(
            (ROOT / "upstreams" / lock["generated_base_manifest"]).read_text(
                encoding="utf-8"
            )
        )
        for entry in exported_fragments:
            self.assertRegex(entry["source_sha256"], r"^[0-9a-f]{64}$")
        for fragment in fragments:
            with self.subTest(fragment=fragment.name):
                self.assertEqual(
                    hashlib.sha256(fragment.read_bytes()).hexdigest(),
                    manifest["files"][fragment.relative_to(GENERATED).as_posix()]["sha256"],
                )
        self.assertEqual(len(overrides), 8)
        self.assertTrue(all("advisory_only" in path.read_text() for path in overrides))

        source_lock = json.loads(
            (runtime / "perfetto-source-lock.json").read_text(encoding="utf-8")
        )
        self.assertEqual(source_lock["schema_version"], 2)
        self.assertEqual(source_lock["official_reference"]["tag"], "v58.2")
        self.assertEqual(
            source_lock["official_reference"]["commit"],
            "add693d8b338ba9599dbcbc3e300b1ab8c000897",
        )
        self.assertEqual(
            source_lock["runtime"]["revision"],
            "99234d73fe356bf7edf6b2cb7afcf2a9eefc5368",
        )
        self.assertEqual(
            source_lock["runtime"]["stdlib_tree"],
            "c4ed7bdb0dfc5c21fb00e3982220d39abe2911bf",
        )
        self.assertEqual(
            source_lock["official_reference"]["skill"]["role"], "gap_check_only"
        )
        fixture_manifest = json.loads(
            (runtime / "fixture-manifest.json").read_text(encoding="utf-8")
        )
        self.assertIn("fixtures", fixture_manifest)

    def portable_skills(self) -> dict:
        """The published runtime manifests, as the exporter's portable Skill view."""
        from tools import export_from_smartperfetto as exporter

        return {
            path.stem: exporter.PortableSkill(
                manifest["runtime_status"],
                frozenset(item["name"] for item in manifest["inputs"]),
            )
            for path in (GENERATED / "runtime/skills").glob("*.json")
            for manifest in [json.loads(path.read_text(encoding="utf-8"))]
        }

    def test_portable_tool_equivalents_name_executable_skills(self) -> None:
        from tools import export_from_smartperfetto as exporter

        skills = self.portable_skills()
        for tool, equivalent in exporter.PORTABLE_TOOL_EQUIVALENTS.items():
            for name in equivalent.skills:
                self.assertEqual(skills[name].status, "executable", tool)
                self.assertIn(f"`{name}`", equivalent.note, tool)
        for strategy in (GENERATED / "strategies").glob("*.md"):
            preamble, body = strategy.read_text(encoding="utf-8").split(
                "## Portable execution commands", 1
            )
            for note in filter(None, exporter.portable_tool_notes(body).split("\n\n")):
                self.assertIn(note, preamble, f"{strategy.name} lacks a portable tool note")

    def test_kept_skill_calls_run_as_exported_skills(self) -> None:
        """Every `invoke_skill(...)` left in a strategy is a real portable run."""
        from tools import export_from_smartperfetto as exporter

        skills = self.portable_skills()
        calls = 0
        for strategy in (GENERATED / "strategies").glob("*.md"):
            text = strategy.read_text(encoding="utf-8")
            calls += len(exporter.SKILL_CALL.findall(text))
            self.assertEqual(exporter.skill_call_rejections(text, skills), [], strategy.name)
        self.assertGreater(calls, 0)
        general = (GENERATED / "strategies/general.strategy.md").read_text(encoding="utf-8")
        self.assertIn("**决策树 — 按用户关注方向路由：**", general)
        self.assertIn('`invoke_skill("cpu_analysis")`', general)

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

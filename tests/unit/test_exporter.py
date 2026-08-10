import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools import export_from_smartperfetto as exporter


ROOT = Path(__file__).resolve().parents[2]
EXPORTER = ROOT / "tools" / "export_from_smartperfetto.py"
CATALOG = ROOT / "catalog" / "smartperfetto-export.json"
MIGRATION_DOC = ROOT / "docs" / "migration-coverage.md"


class ExporterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue(EXPORTER.is_file(), "tools/export_from_smartperfetto.py")

    def load_catalog(self) -> dict[str, object]:
        self.assertTrue(CATALOG.is_file(), "catalog/smartperfetto-export.json")
        return json.loads(CATALOG.read_text(encoding="utf-8"))

    def test_catalog_covers_every_runtime_candidate(self) -> None:
        catalog = self.load_catalog()
        summary = catalog["summary"]
        self.assertEqual(
            summary["skill_yaml_files"],
            summary["runtime_candidates"] + summary["excluded_skill_definitions"],
        )
        self.assertEqual(catalog["summary"]["runtime_candidates"], len(catalog["skills"]))
        self.assertTrue(
            all(
                item["disposition"] in {"exported", "merged", "product-only"}
                for item in catalog["skills"]
            )
        )

    def test_repository_identity_is_stable_across_checkout_protocols(self) -> None:
        expected = "https://github.com/Gracker/SmartPerfetto"
        for remote in (
            "git@github.com:Gracker/SmartPerfetto.git",
            "ssh://git@github.com/Gracker/SmartPerfetto.git",
            "https://github.com/Gracker/SmartPerfetto",
            "https://github.com/Gracker/SmartPerfetto.git",
        ):
            with self.subTest(remote=remote):
                self.assertEqual(exporter.canonical_repository(remote), expected)

    def test_catalog_has_unique_sources_names_and_destinations(self) -> None:
        catalog = self.load_catalog()
        self.assertIn("official_perfetto", catalog)
        self.assertIn("runtime_perfetto", catalog)
        for key in ("source_path", "name"):
            values = [item[key] for item in catalog["skills"]]
            self.assertEqual(len(values), len(set(values)), key)
        destinations = [
            item["destination"]
            for item in catalog["skills"]
            if item["disposition"] != "product-only"
        ]
        self.assertEqual(len(destinations), len(set(destinations)))

    def test_strategies_and_pipeline_docs_are_classified(self) -> None:
        catalog = self.load_catalog()
        self.assertGreaterEqual(len(catalog["strategies"]), 60)
        self.assertEqual(
            len(catalog["strategies"]), catalog["summary"]["strategy_sources"]
        )
        pipeline_docs = catalog["pipeline_docs"]
        self.assertEqual(len(pipeline_docs), 14)
        self.assertEqual(
            [item["source_path"].split("/")[-1].split("_")[0] for item in pipeline_docs],
            [f"S{index:02d}" for index in range(1, 15)],
        )
        self.assertTrue(
            all(item["disposition"] == "exported" for item in pipeline_docs)
        )

    def test_bootstrap_classifier_preserves_domain_boundaries(self) -> None:
        cases = {
            "android_kernel_wakelock_summary": "power-thermal",
            "wakelock_tracking": "power-thermal",
            "block_io_analysis": "io-network-media",
            "frame_blocking_calls": "scrolling",
            "rendering_pipeline_detection": "rendering-pipeline",
            "pipeline_key_slices_overlay": "rendering-pipeline",
            "android_dvfs_counter_stats": "cpu-scheduling",
            "launcher_module": "startup",
            "art_module": "memory",
        }
        for name, expected in cases.items():
            with self.subTest(name=name):
                self.assertEqual(
                    exporter.classify_skill(name, {"type": "atomic"}), expected
                )

    def test_perfetto_source_lock_separates_official_skill_from_runtime(self) -> None:
        official_commit = "a" * 40
        official_tree = "b" * 40
        runtime_revision = "c" * 40
        runtime_tree = "d" * 40
        official_skill = b"official tagged Skill"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "SmartPerfetto"
            (source / "perfetto").mkdir(parents=True)
            data = source / "backend/data"
            data.mkdir(parents=True)
            (data / "perfettoStdlibSymbols.json").write_text(
                json.dumps({"generatedFrom": runtime_revision}), encoding="utf-8"
            )
            (data / "perfettoSqlDocs.json").write_text(
                json.dumps({"generatedFrom": runtime_revision}), encoding="utf-8"
            )
            skill_root = root / "skill"
            lock_path = skill_root / "references/trace-processor-lock.json"
            lock_path.parent.mkdir(parents=True)
            lock_path.write_text(
                json.dumps(
                    {
                        "schema_version": 2,
                        "revision": runtime_revision,
                        "reported_version": "v57.2",
                        "rpc_api_version": 14,
                        "platforms": {"test": {"path": "unused", "sha256": "e" * 64}},
                    }
                ),
                encoding="utf-8",
            )
            catalog = {
                "official_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "tag": "v57.2",
                    "commit": official_commit,
                    "rpc_api_version": 14,
                    "stdlib_tree": official_tree,
                    "official_skill_reference": "ai/skills/perfetto/SKILL-template.md",
                    "official_skill_role": "gap_check_only",
                },
                "runtime_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "reported_version": "v57.2",
                    "revision": runtime_revision,
                    "rpc_api_version": 14,
                    "stdlib_tree": runtime_tree,
                },
            }

            def git_identity(_repository: Path, *arguments: str) -> str:
                revision = arguments[-1]
                values = {
                    "v57.2^{}": official_commit,
                    "v57.2:src/trace_processor/perfetto_sql/stdlib": official_tree,
                    f"{runtime_revision}^{{commit}}": runtime_revision,
                    f"{runtime_revision}:src/trace_processor/perfetto_sql/stdlib": runtime_tree,
                }
                return values[revision]

            with mock.patch.object(exporter, "git_output", side_effect=git_identity), mock.patch.object(
                exporter, "git_file_bytes", return_value=official_skill
            ):
                result = exporter.build_perfetto_source_lock(
                    source, catalog, skill_root=skill_root
                )

        self.assertEqual(result["official_reference"]["commit"], official_commit)
        self.assertEqual(result["official_reference"]["stdlib_tree"], official_tree)
        self.assertEqual(result["runtime"]["revision"], runtime_revision)
        self.assertEqual(result["runtime"]["stdlib_tree"], runtime_tree)
        self.assertNotIn("release", result)
        self.assertEqual(
            result["official_reference"]["skill"]["sha256"],
            exporter.hashlib.sha256(official_skill).hexdigest(),
        )

    def test_perfetto_source_lock_rejects_generated_assets_from_another_revision(self) -> None:
        runtime_revision = "c" * 40
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "SmartPerfetto"
            (source / "perfetto").mkdir(parents=True)
            data = source / "backend/data"
            data.mkdir(parents=True)
            (data / "perfettoStdlibSymbols.json").write_text(
                json.dumps({"generatedFrom": "f" * 40}), encoding="utf-8"
            )
            (data / "perfettoSqlDocs.json").write_text(
                json.dumps({"generatedFrom": runtime_revision}), encoding="utf-8"
            )
            skill_root = root / "skill"
            lock_path = skill_root / "references/trace-processor-lock.json"
            lock_path.parent.mkdir(parents=True)
            lock_path.write_text(
                json.dumps(
                    {
                        "schema_version": 2,
                        "revision": runtime_revision,
                        "reported_version": "v57.2",
                        "rpc_api_version": 14,
                        "platforms": {"test": {"path": "unused", "sha256": "e" * 64}},
                    }
                ),
                encoding="utf-8",
            )
            catalog = {
                "official_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "tag": "v57.2",
                    "commit": "a" * 40,
                    "rpc_api_version": 14,
                    "stdlib_tree": "b" * 40,
                    "official_skill_reference": "ai/skills/perfetto/SKILL-template.md",
                    "official_skill_role": "gap_check_only",
                },
                "runtime_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "reported_version": "v57.2",
                    "revision": runtime_revision,
                    "rpc_api_version": 14,
                    "stdlib_tree": "d" * 40,
                },
            }

            def git_identity(_repository: Path, *arguments: str) -> str:
                revision = arguments[-1]
                values = {
                    "v57.2^{}": "a" * 40,
                    "v57.2:src/trace_processor/perfetto_sql/stdlib": "b" * 40,
                    f"{runtime_revision}^{{commit}}": runtime_revision,
                    f"{runtime_revision}:src/trace_processor/perfetto_sql/stdlib": "d" * 40,
                }
                return values[revision]

            with mock.patch.object(exporter, "git_output", side_effect=git_identity), mock.patch.object(
                exporter, "git_file_bytes", return_value=b"official tagged Skill"
            ):
                with self.assertRaisesRegex(
                    exporter.ExportError,
                    "perfettoStdlibSymbols.json.*does not match runtime revision",
                ):
                    exporter.build_perfetto_source_lock(
                        source, catalog, skill_root=skill_root
                    )

    def test_migration_coverage_is_rendered_from_catalog(self) -> None:
        catalog = self.load_catalog()
        expected = exporter.render_migration_coverage(catalog)
        self.assertEqual(MIGRATION_DOC.read_text(encoding="utf-8"), expected)
        self.assertIn(catalog["source"]["commit"], expected)
        for count in (
            catalog["summary"]["runtime_candidates"],
            catalog["summary"]["strategy_sources"],
            catalog["summary"]["pipeline_docs"],
        ):
            self.assertIn(str(count), expected)


if __name__ == "__main__":
    unittest.main()

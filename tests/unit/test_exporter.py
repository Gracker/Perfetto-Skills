import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

from tools import export_from_smartperfetto as exporter


ROOT = Path(__file__).resolve().parents[2]
SMARTPERFETTO = Path(
    os.environ.get("SMARTPERFETTO_SOURCE", ROOT.parent / "SmartPerfetto")
).expanduser().resolve()
EXPORTER = ROOT / "tools" / "export_from_smartperfetto.py"
CATALOG = ROOT / "catalog" / "smartperfetto-export.json"
MIGRATION_DOC = ROOT / "docs" / "migration-coverage.md"


class ExporterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue(EXPORTER.is_file(), "tools/export_from_smartperfetto.py")
        self.assertTrue(
            (SMARTPERFETTO / "backend" / "skills" / "public-export.yaml").is_file(),
            "SmartPerfetto backend/skills/public-export.yaml",
        )

    def load_catalog(self) -> dict[str, object]:
        self.assertTrue(CATALOG.is_file(), "catalog/smartperfetto-export.json")
        return json.loads(CATALOG.read_text(encoding="utf-8"))

    def test_catalog_covers_every_runtime_candidate(self) -> None:
        subprocess.run(
            [
                sys.executable,
                str(EXPORTER),
                "--source",
                str(SMARTPERFETTO),
                "--check",
            ],
            cwd=ROOT,
            check=True,
        )
        catalog = self.load_catalog()
        self.assertEqual(catalog["summary"]["skill_yaml_files"], 236)
        self.assertEqual(catalog["summary"]["runtime_candidates"], 231)
        self.assertEqual(catalog["summary"]["excluded_skill_definitions"], 5)
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
        self.assertGreaterEqual(len(catalog["pipeline_docs"]), 30)
        self.assertTrue(
            all(item["disposition"] == "exported" for item in catalog["pipeline_docs"])
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

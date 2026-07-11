import copy
import json
from pathlib import Path
import tempfile
import unittest

from tools import validate_catalog


class CatalogValidationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.skill_root = Path(self.temporary.name) / "skill"
        destination = self.skill_root / "references/generated/skills/example.md"
        destination.parent.mkdir(parents=True)
        destination.write_text("# Example\n", encoding="utf-8")
        self.catalog = {
            "schema_version": 1,
            "public_skill": "perfetto-performance-analysis",
            "source": {
                "repository": "https://example.test/SmartPerfetto.git",
                "commit": "a" * 40,
                "dirty": False,
                "policy_path": "backend/skills/public-export.yaml",
                "policy_sha256": "b" * 64,
            },
            "summary": {
                "skill_yaml_files": 1,
                "runtime_candidates": 1,
                "excluded_skill_definitions": 0,
                "runtime_types": {"atomic": 1},
                "strategy_sources": 0,
                "exported_strategy_sources": 0,
                "product_only_strategy_sources": 0,
                "pipeline_docs": 0,
            },
            "skills": [
                {
                    "name": "example",
                    "source_path": "backend/skills/atomic/example.skill.yaml",
                    "source_sha256": "c" * 64,
                    "version": "1.0",
                    "runtime_type": "atomic",
                    "workflow": "trace-overview",
                    "disposition": "exported",
                    "destination": "references/generated/skills/example.md",
                }
            ],
            "strategies": [],
            "pipeline_docs": [],
        }

    def test_accepts_complete_catalog(self) -> None:
        validate_catalog.validate_catalog(self.catalog, self.skill_root)

    def test_rejects_duplicate_destination(self) -> None:
        broken = copy.deepcopy(self.catalog)
        duplicate = copy.deepcopy(broken["skills"][0])
        duplicate["name"] = "duplicate"
        duplicate["source_path"] = "backend/skills/atomic/duplicate.skill.yaml"
        broken["skills"].append(duplicate)
        broken["summary"]["runtime_candidates"] = 2
        broken["summary"]["skill_yaml_files"] = 2
        broken["summary"]["runtime_types"]["atomic"] = 2
        with self.assertRaisesRegex(validate_catalog.CatalogValidationError, "destination"):
            validate_catalog.validate_catalog(broken, self.skill_root)

    def test_rejects_missing_generated_file(self) -> None:
        (self.skill_root / "references/generated/skills/example.md").unlink()
        with self.assertRaisesRegex(validate_catalog.CatalogValidationError, "missing"):
            validate_catalog.validate_catalog(self.catalog, self.skill_root)

    def test_cli_reads_catalog(self) -> None:
        catalog_path = Path(self.temporary.name) / "catalog.json"
        catalog_path.write_text(json.dumps(self.catalog), encoding="utf-8")
        self.assertEqual(
            validate_catalog.main(
                [
                    "--catalog",
                    str(catalog_path),
                    "--skill-root",
                    str(self.skill_root),
                ]
            ),
            0,
        )


if __name__ == "__main__":
    unittest.main()

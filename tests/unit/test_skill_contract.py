import json
from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"


class SkillContractTest(unittest.TestCase):
    def test_frontmatter_is_portable_and_starts_at_byte_zero(self) -> None:
        skill_md = SKILL / "SKILL.md"
        self.assertTrue(skill_md.is_file(), "SKILL.md")
        text = skill_md.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\n"))
        frontmatter = yaml.safe_load(text.split("---", 2)[1])
        self.assertEqual(frontmatter["name"], SKILL.name)
        self.assertIn("Use for", frontmatter["description"])
        self.assertLessEqual(len(frontmatter["description"]), 1024)
        self.assertEqual(
            set(frontmatter), {"name", "description", "license", "metadata"}
        )

    def test_all_workflow_files_exist_and_are_directly_linked(self) -> None:
        index_path = SKILL / "references" / "workflow-index.json"
        self.assertTrue(index_path.is_file(), "references/workflow-index.json")
        index = json.loads(index_path.read_text(encoding="utf-8"))
        self.assertEqual(index["schema_version"], 1)
        self.assertEqual(len(index["workflows"]), 14)
        skill_text = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        for workflow in index["workflows"]:
            reference = SKILL / workflow["reference"]
            self.assertTrue(reference.is_file(), workflow["id"])
            self.assertIn(workflow["reference"], skill_text, workflow["id"])

    def test_codex_metadata_is_optional_and_self_contained(self) -> None:
        metadata_path = SKILL / "agents" / "openai.yaml"
        self.assertTrue(metadata_path.is_file(), "agents/openai.yaml")
        metadata = yaml.safe_load(metadata_path.read_text(encoding="utf-8"))
        self.assertEqual(
            set(metadata["interface"]),
            {"display_name", "short_description", "default_prompt"},
        )
        self.assertIn(
            "$perfetto-performance-analysis",
            metadata["interface"]["default_prompt"],
        )

    def test_report_schema_requires_evidence_and_limitations(self) -> None:
        schema_path = SKILL / "assets" / "report-schema.json"
        self.assertTrue(schema_path.is_file(), "assets/report-schema.json")
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        required = set(schema["required"])
        self.assertTrue(
            {"trace", "findings", "evidence", "limitations"}.issubset(required)
        )

    def test_portable_parameter_and_comparison_adapters_exist(self) -> None:
        for relative in (
            "scripts/perfetto_compare.py",
            "assets/comparison-input-schema.json",
        ):
            self.assertTrue((SKILL / relative).is_file(), relative)
        query_help = (SKILL / "scripts/perfetto_query.py").read_text(encoding="utf-8")
        for option in ("--param", "--result", "--module", "--max-output-bytes"):
            self.assertIn(option, query_help)


if __name__ == "__main__":
    unittest.main()

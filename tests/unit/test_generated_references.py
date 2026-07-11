import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"
CATALOG_PATH = ROOT / "catalog" / "smartperfetto-export.json"
GENERATED = SKILL / "references" / "generated"


class GeneratedReferenceTest(unittest.TestCase):
    def load_catalog(self) -> dict[str, object]:
        return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    def test_every_exported_catalog_entry_has_generated_destination(self) -> None:
        catalog = self.load_catalog()
        for collection in ("skills", "strategies", "pipeline_docs"):
            for item in catalog[collection]:
                if item["disposition"] not in {"exported", "merged"}:
                    continue
                path = SKILL / item["destination"]
                self.assertTrue(path.is_file(), item["source_path"])
                prefix = path.read_text(encoding="utf-8")[:800]
                self.assertIn("GENERATED FILE", prefix, item["source_path"])
                self.assertIn(item["source_path"], prefix, item["source_path"])
                self.assertIn(item["source_sha256"], prefix, item["source_path"])

    def test_generated_sql_files_are_nonempty_and_have_provenance(self) -> None:
        sql_files = list((GENERATED / "sql").rglob("*.sql"))
        self.assertGreater(len(sql_files), 100)
        for path in sql_files:
            content = path.read_text(encoding="utf-8")
            self.assertTrue(content.strip(), path)
            self.assertIn("GENERATED FILE", content[:500], path)
            self.assertIn("Source:", content[:500], path)

    def test_generated_text_has_no_trailing_whitespace(self) -> None:
        for path in GENERATED.rglob("*"):
            if not path.is_file():
                continue
            for line_number, line in enumerate(
                path.read_text(encoding="utf-8").splitlines(), start=1
            ):
                self.assertEqual(line, line.rstrip(), f"{path}:{line_number}")

    def test_all_pipeline_definitions_and_docs_are_exported(self) -> None:
        catalog = self.load_catalog()
        definitions = [
            item
            for item in catalog["skills"]
            if item["runtime_type"] == "pipeline_definition"
        ]
        self.assertEqual(len(definitions), 31)
        self.assertEqual(len(catalog["pipeline_docs"]), 32)
        self.assertTrue(all((SKILL / item["destination"]).is_file() for item in definitions))

    def test_generated_catalog_records_provenance_and_transformations(self) -> None:
        generated_catalog = json.loads(
            (GENERATED / "catalog.json").read_text(encoding="utf-8")
        )
        source_catalog = self.load_catalog()
        self.assertEqual(
            generated_catalog["source_commit"], source_catalog["source"]["commit"]
        )
        self.assertEqual(generated_catalog["schema_version"], 1)
        self.assertIn("transformations", generated_catalog)

    def test_strategy_frontmatter_is_not_exported_as_agent_instructions(self) -> None:
        startup = (
            GENERATED / "strategies" / "startup.strategy.md"
        ).read_text(encoding="utf-8")
        self.assertNotIn("\nscene: startup\n", startup)
        generated_catalog = json.loads(
            (GENERATED / "catalog.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any(
                item["source_path"] == "backend/strategies/startup.strategy.md"
                and item["reason"] == "non-portable frontmatter"
                for item in generated_catalog["transformations"]
            )
        )


if __name__ == "__main__":
    unittest.main()

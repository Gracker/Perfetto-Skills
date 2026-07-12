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
        self.assertEqual(generated_catalog["schema_version"], 2)
        self.assertIn("transformations", generated_catalog)

    def test_strategy_frontmatter_is_preserved_as_portable_metadata(self) -> None:
        startup = (
            GENERATED / "strategies" / "startup.strategy.md"
        ).read_text(encoding="utf-8")
        self.assertIn("## Portable strategy metadata", startup)
        self.assertIn("\nscene: startup\n", startup)

    def test_strategy_references_remove_product_tool_dependencies(self) -> None:
        strategy_text = "\n".join(
            path.read_text(encoding="utf-8")
            for directory in (GENERATED / "strategies", GENERATED / "knowledge")
            for path in directory.glob("*.md")
        )
        for token in (
            "submit_plan",
            "invoke_skill",
            "fetch_artifact",
            "create_artifact",
            "navigate_timeline",
            "pin_tracks",
            "execute_sql_on",
            "list_skills",
            "analysis_result_snapshot",
            "get_comparison_context",
            "compare_skill",
            "perfetto_query_by_trace_side",
            "referenceTraceId",
            "tracePairContext",
            "AnalysisResultSnapshot",
            "snapshot_ids",
            "perfetto_skill_run",
            "read_evidence_bundle",
            "portable_checklist",
            "update_plan_phase",
            "lookup_strategy_detail",
            "lookup_knowledge",
            "submit_hypothesis",
            "resolve_hypothesis",
            "flag_uncertainty",
            "write_analysis_note",
            "detect_architecture",
            "lookup_sql_schema",
            "process_identity_resolver",
        ):
            self.assertNotIn(token, strategy_text, token)
        self.assertIn(
            "`execute_sql(...)` examples mean to run the contained SQL through "
            "`perfetto_query.py`",
            strategy_text,
        )
        self.assertIn("perfetto_skill.py run", strategy_text)
        self.assertIn("perfetto_compare.py", strategy_text)

    def test_comparison_reference_uses_file_adapter_not_product_snapshots(self) -> None:
        comparison = (
            GENERATED / "skills" / "multi_trace_result_comparison.md"
        ).read_text(encoding="utf-8")
        self.assertIn("perfetto_compare.py", comparison)
        for token in (
            "snapshot_ids",
            "baseline_snapshot_id",
            "analysis_result_snapshot",
            "ComparisonMatrix",
        ):
            self.assertNotIn(token, comparison)

    def test_sql_in_parameters_are_documented_as_json_arrays(self) -> None:
        for name in ("cpu_idle_analysis.md", "pipeline_key_slices_overlay.md"):
            content = (GENERATED / "skills" / name).read_text(encoding="utf-8")
            self.assertIn("type: json_array", content, name)
            self.assertIn("pass a JSON array through --param", content, name)
            self.assertIn("source_type: string", content, name)


if __name__ == "__main__":
    unittest.main()

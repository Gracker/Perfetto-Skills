import hashlib
from pathlib import Path
import tempfile
import unittest

from tools.validate_all_queries import validate_query, validate_sql_syntax


class AllQueryValidationTest(unittest.TestCase):
    def test_syntax_probe_rejects_invalid_sql_but_allows_missing_trace_schema(self) -> None:
        self.assertTrue(validate_sql_syntax("SELEKT definitely broken;"))
        self.assertEqual(validate_sql_syntax("SELECT * FROM trace_only_table;"), [])
        self.assertEqual(
            validate_sql_syntax(
                "-- generated header\nCREATE OR REPLACE PERFETTO FUNCTION local_fn(x LONG) "
                "RETURNS LONG AS SELECT $x;"
            ),
            [],
        )
        self.assertEqual(
            validate_sql_syntax(
                "/* generated header */\nCREATE OR REPLACE PERFETTO MACRO local_rows() "
                "RETURNS TABLE AS (SELECT 1);"
            ),
            [],
        )
        self.assertEqual(
            validate_sql_syntax("CREATE PERFETTO INDEX local_idx ON local_table(value);"),
            [],
        )
        self.assertTrue(
            validate_sql_syntax(
                "CREATE PERFETTO FUNCTION broken() RETURNS LONG AS SELEKT 1;"
            )
        )

    def test_syntax_probe_treats_graph_macro_table_as_missing_schema(self) -> None:
        sql = """
        SELECT *
        FROM _graph_aggregating_scan!(
          (SELECT id AS source_node_id, parent_id AS dest_node_id FROM graph),
          (SELECT id, size FROM leaves),
          (size),
          (SELECT id, SUM(size) AS size FROM $table GROUP BY id)
        );
        """
        self.assertEqual(validate_sql_syntax(sql), [])

    def test_reports_four_validation_axes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sql = root / "sql/example.sql"
            sql.parent.mkdir()
            sql.write_text("SELECT 1;", encoding="utf-8")
            query = {
                "id": "skill/step",
                "path": "sql/example.sql",
                "sha256": hashlib.sha256(b"SELECT 1;").hexdigest(),
                "sql_dependencies": {"declared_modules": ["android.example"]},
                "template": {"parameters": [], "fragments": [], "result_dependencies": []},
                "compatibility": {
                    "android": {
                        str(api): {"status": "capability_gated"}
                        for api in range(28, 38)
                    }
                },
                "validation": {
                    "runtime_compatible": True,
                    "execution_verified": True,
                    "semantic_verified": True,
                    "fixtures": ["fixture-a"],
                },
            }
            result = validate_query(
                query,
                root,
                stdlib_modules={"android.example"},
                fixtures={"fixture-a"},
                semantic_queries={"skill/step"},
            )
            self.assertEqual(
                {key: result[key] for key in ("static_valid", "runtime_compatible", "execution_verified", "semantic_verified")},
                {
                    "static_valid": True,
                    "runtime_compatible": True,
                    "execution_verified": True,
                    "semantic_verified": True,
                },
            )

    def test_hash_module_and_semantic_mismatch_fail_truthfully(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sql = root / "query.sql"
            sql.write_text("SELECT 1;", encoding="utf-8")
            query = {
                "id": "skill/step",
                "path": "query.sql",
                "sha256": "0" * 64,
                "sql_dependencies": {"declared_modules": ["missing.module"]},
                "template": {"parameters": [], "fragments": [], "result_dependencies": []},
                "compatibility": {
                    "android": {
                        str(api): {"status": "capability_gated"}
                        for api in range(28, 38)
                    }
                },
                "validation": {
                    "runtime_compatible": True,
                    "execution_verified": True,
                    "semantic_verified": True,
                    "fixtures": ["missing-fixture"],
                },
            }
            result = validate_query(
                query,
                root,
                stdlib_modules=set(),
                fixtures=set(),
                semantic_queries=set(),
            )
            self.assertFalse(result["static_valid"])
            self.assertFalse(result["semantic_verified"])
            self.assertTrue(any("hash" in error for error in result["errors"]))
            self.assertTrue(any("module" in error for error in result["errors"]))

    def test_rejects_placeholder_fragment_dependency_and_compatibility_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sql = root / "query.sql"
            sql.write_text("SELECT ${package};", encoding="utf-8")
            query = {
                "id": "skill/step",
                "path": "query.sql",
                "sha256": hashlib.sha256(sql.read_bytes()).hexdigest(),
                "sql_dependencies": {
                    "declared_modules": [],
                    "required_tables": ["missing_table"],
                    "setup_queries": ["missing/setup"],
                },
                "template": {
                    "parameters": [],
                    "fragments": [{"source_path": "source/missing.sql", "source_sha256": "0" * 64}],
                    "result_dependencies": ["missing_result"],
                },
                "compatibility": {"android": {}},
                "validation": {},
            }
            result = validate_query(
                query,
                root,
                stdlib_modules=set(),
                fixtures=set(),
                semantic_queries=set(),
                query_ids={"skill/step"},
                required_symbols=set(),
                result_names=set(),
            )
            self.assertFalse(result["static_valid"])
            for fragment in (
                "parameters",
                "fragment",
                "setup query",
                "result dependency",
                "compatibility",
                "required table",
            ):
                self.assertTrue(any(fragment in error for error in result["errors"]), result["errors"])


if __name__ == "__main__":
    unittest.main()

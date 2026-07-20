from contextlib import redirect_stdout
from io import StringIO
import json
from pathlib import Path
import tempfile
import unittest

from tests.support import load_skill_script


guardrails = load_skill_script("perfetto_sql_guardrails")
analyze_sql = guardrails.analyze_sql
main = guardrails.main


class SqlGuardrailTest(unittest.TestCase):
    def test_requires_non_overlap_proof_for_each_span_join(self) -> None:
        issues = analyze_sql(
            """
            DROP TABLE IF EXISTS first_join;
            -- perfetto-span-join-non-overlap-proof: fixture first-inputs
            CREATE VIRTUAL TABLE first_join
            USING SPAN_JOIN(a PARTITIONED utid, b PARTITIONED utid);

            DROP TABLE IF EXISTS second_join;
            CREATE VIRTUAL TABLE second_join
            USING SPAN_JOIN(c PARTITIONED upid, d PARTITIONED upid);
            """
        )

        self.assertEqual(
            [issue.rule_id for issue in issues if issue.severity == "error"],
            ["span-join-non-overlap"],
        )
        self.assertIn("USING SPAN_JOIN(c PARTITIONED upid", issues[-1].snippet)

    def test_rejects_mismatched_partitions_and_non_idempotent_virtual_table(self) -> None:
        issues = analyze_sql(
            """
            -- perfetto-span-join-non-overlap-proof: assertion inputs-disjoint
            CREATE VIRTUAL TABLE joined
            USING SPAN_LEFT_JOIN(a PARTITIONED utid, b PARTITIONED upid);
            """
        )

        errors = {issue.rule_id: issue.message for issue in issues if issue.severity == "error"}
        self.assertIn("same partition key", errors["span-join-safety"])
        self.assertIn("DROP TABLE IF EXISTS", errors["span-join-idempotency"])

    def test_rejects_span_join_without_a_partition_key(self) -> None:
        issues = analyze_sql(
            """
            DROP TABLE IF EXISTS joined;
            -- perfetto-span-join-non-overlap-proof: assertion inputs-disjoint
            CREATE VIRTUAL TABLE joined
            USING SPAN_JOIN(a, b);
            """
        )

        errors = {issue.rule_id: issue.message for issue in issues if issue.severity == "error"}
        self.assertIn("PARTITIONED", errors["span-join-safety"])

    def test_literal_empty_and_non_adjacent_markers_do_not_count(self) -> None:
        issues = analyze_sql(
            """
            SELECT 'perfetto-span-join-non-overlap-proof: literal';
            -- perfetto-span-join-non-overlap-proof:
            DROP TABLE IF EXISTS joined;
            CREATE VIRTUAL TABLE joined
            USING SPAN_JOIN(a PARTITIONED utid, b PARTITIONED utid);
            """
        )

        self.assertTrue(
            any(issue.rule_id == "span-join-non-overlap" for issue in issues)
        )

    def test_reports_non_blocking_sql_advisories(self) -> None:
        issues = analyze_sql(
            """
            CREATE PERFETTO VIEW events AS
            SELECT SUM(slice.dur)
            FROM slice
            JOIN args ON args.arg_set_id = slice.arg_set_id
            WHERE slice.name LIKE '%work%'
              AND slice.ts >= ${start_ts};
            """
        )

        advisory_rules = {
            issue.rule_id for issue in issues if issue.severity == "advisory"
        }
        self.assertTrue(
            {
                "prefer-glob-for-like",
                "safe-duration-boundary",
                "overlap-range-filter",
                "idempotent-create",
                "safe-arg-extraction",
            }.issubset(advisory_rules)
        )
        self.assertFalse(any(issue.severity == "error" for issue in issues))

    def test_cli_emits_json_and_strict_mode_fails_on_advisories(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "query.sql"
            path.write_text("SELECT * FROM slice WHERE name LIKE '%work%';\n", encoding="utf-8")
            output = StringIO()
            with redirect_stdout(output):
                result = main([str(path), "--format", "json", "--strict"])

        self.assertEqual(result, 1)
        payload = json.loads(output.getvalue())
        self.assertEqual(payload["summary"]["errors"], 0)
        self.assertEqual(payload["summary"]["advisories"], 1)


if __name__ == "__main__":
    unittest.main()

"""A warm trace processor session must answer exactly as a fresh process does."""

import os
from pathlib import Path
import re
import shutil
import tempfile
import unittest

from tests.support import ROOT, load_skill_script


TRACE = ROOT / "fixtures/smoke/api32_startup_warm.perfetto-trace"
STARTUPS = "INCLUDE PERFETTO MODULE android.startup.startups;\n"


@unittest.skipUnless(os.environ.get("PERFETTO_TRACE_PROCESSOR"), "trace processor not configured")
class TraceProcessorSessionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.common = load_skill_script("_common")
        self.processor = os.environ["PERFETTO_TRACE_PROCESSOR"]

    def session(self):
        return self.common.trace_processor_session(TRACE, trace_processor=self.processor)

    def query(self, sql: str | None = None, *, trace: Path = TRACE, **options: object):
        return self.common.run_query(trace, sql=sql, trace_processor=self.processor, **options)

    def assert_same_failure(self, sql: str) -> None:
        """A failing query reports the same traceback in either mode."""
        with self.assertRaises(self.common.QueryError) as fresh:
            self.query(sql)
        with self.session():
            with self.assertRaises(self.common.QueryError) as warm:
                self.query(sql)

        def traceback(error: BaseException) -> str:
            # Only a one-shot run logs loading the trace.
            return re.sub(r"\[[0-9.]+\]\s+\S+\s+Trace loaded:[^\n]*\n", "", str(error))

        self.assertEqual(traceback(warm.exception), traceback(fresh.exception))

    def test_queries_share_one_load_and_print_identical_bytes(self) -> None:
        queries = [
            STARTUPS + "SELECT startup_id, ts, dur, package FROM android_startups ORDER BY startup_id;",
            STARTUPS + "SELECT COUNT(*) AS n FROM android_startups;\nSELECT 'a,\"b' AS s, NULL AS n, 1.5 AS f;",
            STARTUPS + "CREATE PERFETTO TABLE warm_probe AS SELECT 1 AS id;\n"
            "CREATE PERFETTO INDEX warm_probe_idx ON warm_probe(id);\nSELECT id FROM warm_probe -- trailing",
            STARTUPS + "SELECT 1 AS empty WHERE 0;",
        ]
        fresh = [self.query(sql).stdout for sql in queries]
        with self.session() as session:
            warm = [self.query(sql) for sql in queries]
            self.assertEqual(session.start_count, 1)
            address = session.address
        self.assertEqual([result.stdout for result in warm], fresh)
        self.assertTrue(all("--remote" in result.command for result in warm))
        self.assertFalse(Path(address).exists())
        self.assertFalse(Path(address).parent.exists())

    def test_rolled_back_objects_can_be_created_again(self) -> None:
        sql = (
            "CREATE PERFETTO TABLE rollback_table AS SELECT 1 AS id;\n"
            "CREATE PERFETTO INDEX rollback_idx ON rollback_table(id);\n"
            "CREATE PERFETTO VIEW rollback_view AS SELECT 1 AS id;\n"
            "CREATE TABLE rollback_plain AS SELECT 1 AS id;\n"
            "SELECT COUNT(*) AS n FROM rollback_table;"
        )
        with self.session() as session:
            first = self.query(sql)
            second = self.query(sql)
            self.assertEqual(session.start_count, 1)
        self.assertEqual(first.stdout, second.stdout)

    def test_definitions_a_rollback_keeps_run_one_shot(self) -> None:
        function = "CREATE PERFETTO FUNCTION warm_fn() RETURNS INT AS SELECT 1;\nSELECT warm_fn() AS v;"
        macro = "CREATE PERFETTO MACRO warm_macro() RETURNS Expr AS 2;\nSELECT warm_macro!() AS v;"
        with self.session() as session:
            for sql in (function, function, macro, macro):
                result = self.query(sql)
                self.assertNotIn("--remote", result.command)
            self.assertEqual(session.start_count, 0)
            # The session stays clean: an undefined function still fails.
            with self.assertRaisesRegex(self.common.QueryError, "warm_fn"):
                self.query("SELECT warm_fn() AS v;")

    def test_a_query_sees_only_the_modules_it_includes(self) -> None:
        with self.session() as session:
            self.query(STARTUPS + "SELECT COUNT(*) AS n FROM android_startups;")
            with self.assertRaisesRegex(self.common.QueryError, "android_startups"):
                self.query("SELECT COUNT(*) AS n FROM android_startups;")
            self.assertEqual(session.modules, frozenset())
            self.query("SELECT 1 AS v;")
            self.query(STARTUPS + "SELECT COUNT(*) AS n FROM android_startups;")
            self.assertEqual(session.modules, frozenset({"android.startup.startups"}))
            # Only dropping a loaded module costs a reload; a failure does not.
            self.assertEqual(session.start_count, 2)

    def test_failures_report_the_one_shot_location(self) -> None:
        self.assert_same_failure(
            STARTUPS + STARTUPS.strip() + " SELECT 1 AS ok;\n\n  SELECT * FROM table_that_does_not_exist;"
        )
        self.assert_same_failure("INCLUDE PERFETTO MODULE no.such.module;\nSELECT 1;")
        self.assert_same_failure(STARTUPS + "SELECT 1 AS a; SELECT missing_column FROM android_startups;")

    def test_failed_body_rolls_back_and_failed_include_discards_session(self) -> None:
        with self.session() as session:
            with self.assertRaises(self.common.QueryError):
                self.query(
                    "CREATE PERFETTO TABLE failure_probe AS SELECT 1 AS id;\n"
                    "SELECT * FROM table_that_does_not_exist;"
                )
            result = self.query("CREATE PERFETTO TABLE failure_probe AS SELECT 2 AS id;\nSELECT id FROM failure_probe;")
            self.assertEqual(self.common.parse_csv_output(result.stdout), [{"id": 2}])
            self.assertEqual(session.start_count, 1)
            with self.assertRaises(self.common.QueryError):
                self.query("INCLUDE PERFETTO MODULE no.such.module;\nSELECT 1;")
            self.assertIsNone(session._process)

    def test_output_limit_discards_the_server_before_reuse(self) -> None:
        with self.session() as session:
            with self.assertRaisesRegex(self.common.QueryError, "output limit"):
                self.query("SELECT HEX(randomblob(100000)) AS payload;", max_output_bytes=4096)
            result = self.query("SELECT 1 AS value;")
            self.assertEqual(self.common.parse_csv_output(result.stdout), [{"value": 1}])
            self.assertEqual(session.start_count, 2)

    def test_timeout_covers_the_load_and_discards_the_server(self) -> None:
        slow = (
            "WITH RECURSIVE numbers(n) AS (SELECT 0 UNION ALL "
            "SELECT n + 1 FROM numbers WHERE n < 1000000000) SELECT SUM(n) FROM numbers;"
        )
        with self.session() as session:
            self.query("SELECT 1 AS value;")
            with self.assertRaisesRegex(self.common.QueryError, r"timed out after 0\.5s"):
                self.query(slow, timeout=0.5)
            self.assertIsNone(session._process)
            with self.assertRaisesRegex(self.common.QueryError, r"timed out after 0\.001s"):
                self.query("SELECT 1 AS value;", timeout=0.001)
            result = self.query("SELECT 1 AS value;")
            self.assertEqual(self.common.parse_csv_output(result.stdout), [{"value": 1}])

    def test_text_that_only_looks_like_sql_stays_in_place(self) -> None:
        cases = [
            "SELECT 'before\nINCLUDE PERFETTO MODULE android.startup.startups;\nafter' AS value;",
            "SELECT 'CREATE PERFETTO FUNCTION f() RETURNS INT AS SELECT 1; RUN_METRIC(' AS value;",
            "-- INCLUDE PERFETTO MODULE android.startup.startups;\nSELECT 1 AS value; /* ; */",
        ]
        fresh = [self.query(sql).stdout for sql in cases]
        with self.session() as session:
            warm = [self.query(sql) for sql in cases]
            self.assertEqual(session.start_count, 1)
        self.assertEqual([result.stdout for result in warm], fresh)
        self.assertTrue(all("--remote" in result.command for result in warm))

    def test_nested_sessions_share_and_other_traces_run_one_shot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            other = Path(temporary) / "other.perfetto-trace"
            shutil.copyfile(TRACE, other)
            sql_file = Path(temporary) / "query.sql"
            sql_file.write_text(STARTUPS + "SELECT COUNT(*) AS n FROM android_startups;", encoding="utf-8")
            with self.session() as owner:
                with self.session() as nested:
                    self.assertIs(nested, owner)
                    self.query("SELECT 2 AS value;")
                from_file = self.query(sql_file=sql_file)
                foreign = self.query("SELECT 3 AS value;", trace=other)
                self.assertEqual(owner.start_count, 1)
            self.assertIn("--remote", from_file.command)
            self.assertNotIn("--remote", foreign.command)
            self.assertEqual(
                from_file.stdout,
                self.query(sql_file=sql_file).stdout,
            )


if __name__ == "__main__":
    unittest.main()

"""Which SQL a warm trace processor session may run, and how it falls back."""

from pathlib import Path
import tempfile
import unittest

from tests.support import load_skill_script


STARTUPS = "INCLUDE PERFETTO MODULE android.startup.startups;\n"


class SessionPlanTest(unittest.TestCase):
    def setUp(self) -> None:
        self.common = load_skill_script("_common")

    def plan(self, sql: str):
        return self.common._session_plan(sql)

    def test_leading_includes_split_from_a_rollback_safe_body(self) -> None:
        sql = STARTUPS + "include perfetto module android.frames.timeline -- why\n;SELECT 1;\nWITH x AS (SELECT 1) SELECT * FROM x"
        plan = self.plan(sql)
        self.assertEqual(plan.modules, frozenset({"android.startup.startups", "android.frames.timeline"}))
        self.assertEqual(plan.includes + plan.body, sql)
        self.assertTrue(plan.body.startswith("SELECT 1;"))

    def test_rollback_safe_statement_kinds(self) -> None:
        for statement in (
            "SELECT 1",
            "VALUES (1)",
            "WITH x AS (SELECT 1) SELECT * FROM x",
            "CREATE PERFETTO TABLE t AS SELECT 1 AS id",
            "create or replace perfetto table t AS SELECT 1 AS id",
            "CREATE OR REPLACE PERFETTO VIEW v AS SELECT 1",
            "CREATE PERFETTO INDEX i ON t(id)",
            "CREATE TEMP TABLE t AS SELECT 1",
            "CREATE VIEW v AS SELECT 1",
        ):
            with self.subTest(statement=statement):
                self.assertIsNotNone(self.plan(statement + ";"))

    def test_effects_a_rollback_keeps_run_one_shot(self) -> None:
        for sql in (
            "CREATE PERFETTO FUNCTION f() RETURNS INT AS SELECT 1; SELECT f();",
            "CREATE OR REPLACE PERFETTO MACRO m() RETURNS Expr AS 1; SELECT m!();",
            "SELECT RUN_METRIC('android/android_startup.sql');",
            "SELECT IMPORT('android.startup.startups');",
            "SELECT 1; INCLUDE PERFETTO MODULE android.startup.startups;",
            "INCLUDE PERFETTO MODULE android.*; SELECT 1;",
            "BEGIN; SELECT 1;",
            "PRAGMA table_info('slice');",
            "DROP TABLE x;",
            "CREATE VIRTUAL TABLE s USING SPAN_JOIN(a, b);",
            "",
            "-- only a comment",
            STARTUPS,
            "SELECT 1; /* unterminated",
            "SELECT 'unterminated",
        ):
            with self.subTest(sql=sql):
                self.assertIsNone(self.plan(sql))

    def test_quoted_and_commented_text_is_not_a_statement(self) -> None:
        for sql in (
            "SELECT 'x; CREATE PERFETTO FUNCTION f() RETURNS INT AS SELECT 1' AS v;",
            'SELECT "RUN_METRIC(" FROM slice;',
            "SELECT 1 -- ; INCLUDE PERFETTO MODULE x;\n;",
            "SELECT [a;b] FROM (SELECT 1 AS [a;b]);",
            "SELECT 'it''s; DROP TABLE x' AS v;",
        ):
            with self.subTest(sql=sql):
                plan = self.plan(sql)
                self.assertIsNotNone(plan)
                self.assertEqual(plan.modules, frozenset())


class SessionFallbackTest(unittest.TestCase):
    def setUp(self) -> None:
        self.common = load_skill_script("_common")

    def test_processor_without_a_unix_server_runs_queries_one_shot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "trace_processor_shell"
            binary.write_text(
                "#!/usr/bin/env python3\n"
                "import sys\n"
                "if sys.argv[1] != 'query' or '--remote' in sys.argv:\n"
                "    sys.exit(2)\n"
                "print('\"value\"')\n"
                "print(1)\n",
                encoding="utf-8",
            )
            binary.chmod(0o755)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            with self.common.trace_processor_session(trace, trace_processor=str(binary)) as session:
                first = self.common.run_query(trace, sql="SELECT 1 AS value;", trace_processor=str(binary))
                second = self.common.run_query(trace, sql="SELECT 1 AS value;", trace_processor=str(binary))
                self.assertTrue(session.unavailable)
                self.assertEqual(session.start_count, 0)
                self.assertEqual(session.address, "")
            for result in (first, second):
                self.assertNotIn("--remote", result.command)
                self.assertEqual(self.common.parse_csv_output(result.stdout), [{"value": 1}])


if __name__ == "__main__":
    unittest.main()

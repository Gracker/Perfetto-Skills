"""A warm trace processor session must answer exactly as a fresh process does."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

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

    def one_shot(self):
        """Count queries that run on a fresh processor instead of the session."""
        return mock.patch.object(self.common, "_run_rpc_once", wraps=self.common._run_rpc_once)

    def cli(self, sql: str) -> str:
        """What `trace_processor_shell query` itself prints for `sql`."""
        limits = self.common._ProcessorLimits(time.monotonic() + 60, 60, 1 << 24)
        return self.common._run_processor(
            (self.processor, "query", "--extra-checks"), (str(TRACE),), sql=sql, sql_file=None, limits=limits,
        ).stdout

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
        with self.one_shot() as one_shot, self.session() as session:
            warm = [self.query(sql) for sql in queries]
            self.assertEqual(session.start_count, 1)
            self.assertEqual(one_shot.call_count, 0)
            child = session._rpc._process
        self.assertEqual([result.stdout for result in warm], fresh)
        self.assertIsNone(session._rpc)
        self.assertIsNotNone(child.poll())

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
        with self.one_shot() as one_shot, self.session() as session:
            for sql in (function, function, macro, macro):
                self.query(sql)
            self.assertEqual(one_shot.call_count, 4)
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
            self.assertIsNone(session._rpc)

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
            self.assertIsNone(session._rpc)
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
        with self.one_shot() as one_shot, self.session() as session:
            warm = [self.query(sql) for sql in cases]
            self.assertEqual(session.start_count, 1)
            self.assertEqual(one_shot.call_count, 0)
        self.assertEqual([result.stdout for result in warm], fresh)

    def test_nested_sessions_share_and_other_traces_run_one_shot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            other = Path(temporary) / "other.perfetto-trace"
            shutil.copyfile(TRACE, other)
            sql_file = Path(temporary) / "query.sql"
            sql_file.write_text(STARTUPS + "SELECT COUNT(*) AS n FROM android_startups;", encoding="utf-8")
            with self.one_shot() as one_shot, self.session() as owner:
                with self.session() as nested:
                    self.assertIs(nested, owner)
                    self.query("SELECT 2 AS value;")
                from_file = self.query(sql_file=sql_file)
                self.assertEqual(one_shot.call_count, 0)
                self.query("SELECT 3 AS value;", trace=other)
                self.assertEqual(one_shot.call_count, 1)
                self.assertEqual(owner.start_count, 1)
            self.assertEqual(
                from_file.stdout,
                self.query(sql_file=sql_file).stdout,
            )


    def test_output_matches_the_cli_except_for_exact_doubles_and_escaped_quotes(self) -> None:
        exact = [
            STARTUPS + "SELECT startup_id, ts, dur, package FROM android_startups ORDER BY startup_id;",
            "SELECT 1 AS a; SELECT 2 AS b WHERE 0; CREATE PERFETTO TABLE t AS SELECT 1 x; SELECT NULL AS n, X'00' AS b;",
            "SELECT 'a,b' AS s, -3 AS i, 9223372036854775807 AS big;",
        ]
        for sql in exact:
            with self.subTest(sql=sql):
                self.assertEqual(self.query(sql).stdout, self.cli(sql))
        rows = self.common.parse_csv_output(self.query("SELECT 1.0 / 3 AS third, 1e-7 AS tiny, 2.5 AS half, 'say \"hi\"' AS s;").stdout)
        self.assertEqual(rows, [{"third": 1 / 3, "tiny": 1e-7, "half": 2.5, "s": 'say "hi"'}])
        self.assertEqual(
            self.cli("SELECT 1.0 / 3 AS third, 1e-7 AS tiny;"), '"third","tiny"\n0.333333,0.000000\n'
        )
        # Several result sets keep the CLI's blank-line layout.
        self.assertEqual(self.query("SELECT 1 AS a; SELECT 2 AS b;").stdout, '"a"\n1\n\n"b"\n2\n')
        with self.assertRaisesRegex(self.common.QueryError, "No valid SQL to run"):
            self.query("-- nothing\n")

    def test_rows_keep_cell_identity_over_rpc(self) -> None:
        result = self.query(
            "SELECT NULL AS n, '[NULL]' AS marker, 'line\nbreak, \"quoted\"' AS text, X'0001' AS blob, "
            "'42' AS numeric_text, 1e-7 AS tiny;"
        )
        self.assertEqual(self.common.query_rows(result), [{
            "n": None, "marker": "[NULL]", "text": 'line\nbreak, "quoted"', "blob": "<raw bytes>",
            "numeric_text": 42, "tiny": 1e-7,
        }])
        many = self.query(
            "WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 200000) "
            "SELECT i, i * 0.5 AS half FROM n;"
        )
        rows = self.common.query_rows(many)
        self.assertEqual((len(rows), rows[-1]), (200000, {"i": 200000, "half": 100000.0}))
        with self.assertRaisesRegex(self.common.QueryError, "output limit"):
            self.query("SELECT 'x' AS a, 'y' AS b;", max_output_bytes=8)

    def group_processes(self, pgid: int) -> list[tuple[int, str]]:
        listing = subprocess.run(["ps", "-A", "-o", "pid=,pgid=,comm="], capture_output=True, text=True, check=True)
        members = []
        for line in listing.stdout.splitlines():
            fields = line.split(None, 2)
            if len(fields) == 3 and int(fields[1]) == pgid:
                members.append((int(fields[0]), fields[2]))
        return members

    def assert_owner_death_ends_processor(self, body: str) -> None:
        """Run `body` in an owner that prints its guardian's group, then dies at once."""
        script = (
            "import os, sys, threading, time\n"
            f"sys.path.insert(0, {str(ROOT)!r})\n"
            "from tests.support import load_skill_script\n"
            "c = load_skill_script('_common')\n"
            f"TRACE, TP = {str(TRACE)!r}, {self.processor!r}\n"
            + body
            + "print(rpc._process.pid, flush=True)\n"
            "os._exit(0)\n"
        )
        pgid = int(subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, check=True).stdout)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if not self.group_processes(pgid):
                return
            time.sleep(0.1)
        members = self.group_processes(pgid)
        for pid, _name in members:
            os.kill(pid, 9)
        self.fail(f"processes outlived their owner: {members}")

    def test_a_dead_owner_takes_its_processor_with_it(self) -> None:
        self.assert_owner_death_ends_processor(
            "cm = c.trace_processor_session(TRACE, trace_processor=TP)\n"
            "session = cm.__enter__()\n"
            "c.run_query(TRACE, sql='SELECT 1 AS v;', trace_processor=TP)\n"
            "rpc = session._rpc\n"
        )

    def test_a_processor_dies_with_its_owner_even_mid_query(self) -> None:
        self.assert_owner_death_ends_processor(
            "rpc = c._TraceProcessorRpc(c.resolve_trace_processor(TP), c.Path(TRACE))\n"
            "limits = c._ProcessorLimits(time.monotonic() + 300, 300, 1 << 20)\n"
            "rpc.begin_query()\n"
            "slow = 'WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n) SELECT SUM(i) FROM n;'\n"
            "errors = []\n"
            "def work():\n"
            "    try:\n"
            "        rpc.run(slow, limits)\n"
            "    except BaseException as error:\n"
            "        errors.append(error)\n"
            "worker = threading.Thread(target=work, daemon=True)\n"
            "worker.start()\n"
            # The processor has loaded the trace, the request has been written,
            # and the query is still running with no answer.
            "deadline = time.monotonic() + 30\n"
            "while (rpc._stderr_bytes == 0 or rpc.requests_written < 1) and time.monotonic() < deadline:\n"
            "    time.sleep(0.05)\n"
            "time.sleep(1.0)\n"
            "if rpc._stderr_bytes == 0 or rpc.requests_written < 1 or errors or not worker.is_alive() or rpc.answered:\n"
            "    print('query did not start', errors, file=sys.stderr)\n"
            "    os._exit(3)\n"
        )

    def test_a_guardian_whose_owner_is_already_gone_starts_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "started"
            completed = subprocess.run(
                [sys.executable, "-c", self.common._RPC_GUARDIAN, "1", sys.executable, "-c",
                 f"open({str(marker)!r}, 'w').close()"],
                capture_output=True, timeout=10, check=False,
            )
            self.assertEqual(completed.returncode, 0)
            self.assertFalse(marker.exists())

if __name__ == "__main__":
    unittest.main()

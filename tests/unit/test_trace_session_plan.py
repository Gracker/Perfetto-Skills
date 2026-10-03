"""Which SQL a warm session may run, the stdio RPC codec, and the CLI fallback."""

from pathlib import Path
import tempfile
import time
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


class RpcCodecTest(unittest.TestCase):
    """The protobuf pieces of the stdio RPC client, against hand-built messages."""

    def setUp(self) -> None:
        self.common = load_skill_script("_common")

    def test_cells_decode_every_type_across_batches(self) -> None:
        c = self.common
        import struct

        first = (
            c._pb_bytes(1, bytes([2, 3, 4, 1]))
            + c._pb_bytes(2, c._pb_varint(-5))
            + c._pb_bytes(3, struct.pack("<d", 1e-7))
            + c._pb_bytes(5, "a\"b,\nc\0".encode())
        )
        second = c._pb_bytes(1, bytes([5, 2])) + c._pb_bytes(4, b"\x00\x01") + c._pb_bytes(2, c._pb_varint(2 ** 40))
        cells = c._rpc_cells([first, second])
        self.assertEqual(cells[:4], [-5, 1e-7, 'a"b,\nc', None])
        self.assertIs(cells[4], c._RAW_BYTES)
        self.assertEqual(cells[5], 2 ** 40)

    def test_csv_keeps_the_cli_shape_with_exact_doubles_and_escaped_strings(self) -> None:
        c = self.common
        result = c._ResultSet(("n", "f", "s", "x", "b"), ((1, 1 / 3, 'say "hi"', None, c._RAW_BYTES),))
        self.assertEqual(
            "".join(result.csv_lines()),
            '"n","f","s","x","b"\n1,0.3333333333333333,"say ""hi""","[NULL]","<raw bytes>"\n',
        )
        self.assertEqual(
            c.parse_csv_output("".join(result.csv_lines())),
            [{"n": 1, "f": 1 / 3, "s": 'say "hi"', "x": None, "b": "<raw bytes>"}],
        )
        self.assertEqual(c.parse_csv_output('"f"\n1e-07\n'), [{"f": 1e-07}])


FAKE_SERVER = """
import json, os, sys
replies = json.load(open(os.environ["FAKE_RPC_REPLIES"]))
stdin, stdout = sys.stdin.buffer, sys.stdout.buffer

def varint():
    shift = value = 0
    while True:
        byte = stdin.read(1)
        if not byte:
            sys.exit(0)
        value |= (byte[0] & 0x7F) << shift
        shift += 7
        if not byte[0] & 0x80:
            return value

for reply in replies:
    varint()
    stdin.read(varint())
    if reply is None:
        sys.exit(3)
    if reply == "hang":
        import time
        time.sleep(60)
    if reply.startswith("stderr:"):
        import time
        sys.stderr.write("x" * int(reply[7:]))
        sys.stderr.flush()
        time.sleep(60)
    if reply == "closeout":
        import os, time
        stdout.close()
        os.close(1)
        time.sleep(60)
    for byte in bytes.fromhex(reply):
        stdout.write(bytes([byte]))
        stdout.flush()
"""


class RpcStreamTest(unittest.TestCase):
    """Framing, multi-message results, late errors and EOF against a fake server."""

    def setUp(self) -> None:
        self.common = load_skill_script("_common")

    def message(self, *, executed=None, tail=None, columns=(), cells=(), varints=(), last=False, error=None, with_output=1):
        c = self.common
        batch = c._pb_bytes(1, bytes(cells)) + c._pb_bytes(2, b"".join(c._pb_varint(v) for v in varints))
        if last:
            batch += c._pb_uint(6, 1)
        result = b"".join(c._pb_bytes(1, name.encode()) for name in columns) + c._pb_bytes(3, batch)
        if error is not None:
            result += c._pb_bytes(2, error.encode())
        result += c._pb_uint(5, with_output)
        statement = c._pb_bytes(1, result)
        if tail is not None:
            statement += c._pb_uint(2, tail)
        if executed is not None:
            statement += c._pb_uint(3, int(executed))
        rpc = c._pb_uint(1, 1) + c._pb_uint(3, 20) + c._pb_bytes(219, statement)
        return c._pb_bytes(1, rpc).hex()

    def run_fake(self, replies, timeout=10.0, max_output_bytes=1 << 20, deadline=None):
        import json
        import os
        import sys
        from unittest import mock

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "replies.json").write_text(json.dumps(replies), encoding="utf-8")
            (root / "server.py").write_text(FAKE_SERVER, encoding="utf-8")
            trace = root / "trace"
            trace.write_bytes(b"")
            limits = self.common._ProcessorLimits(
                deadline if deadline is not None else time.monotonic() + timeout, timeout, max_output_bytes,
            )
            command = (sys.executable, str(root / "server.py"))
            real_popen = self.common.subprocess.Popen
            with mock.patch.dict(os.environ, {"FAKE_RPC_REPLIES": str(root / "replies.json")}):
                with mock.patch.object(
                    self.common.subprocess, "Popen", side_effect=lambda _command, **kwargs: real_popen(command, **kwargs)
                ):
                    rpc = self.common._TraceProcessorRpc(Path("unused"), trace)
                try:
                    return rpc.run("SELECT 1; SELECT 2;", limits)
                finally:
                    rpc.kill()

    def test_a_result_split_over_fragmented_messages(self) -> None:
        result = self.run_fake([
            self.message(executed=True, tail=9, columns=("a",), cells=(2,), varints=(1,))
            + self.message(cells=(2,), varints=(2,), last=True),
            self.message(executed=False, tail=9, last=True),
        ])
        self.assertEqual(result.stdout, '"a"\n1\n2\n')
        self.assertEqual(result.rows, ({"a": 1}, {"a": 2}))

    def test_an_error_after_rows_fails_the_query(self) -> None:
        result = self.run_fake([
            self.message(executed=True, tail=9, columns=("a",), cells=(2,), varints=(1,))
            + self.message(error="interrupted", last=True),
        ])
        self.assertEqual((result.returncode, result.stderr, result.rows), (1, "interrupted", None))

    def test_a_server_that_dies_mid_query_is_an_error_not_a_fallback(self) -> None:
        with self.assertRaisesRegex(self.common.QueryError, "exited during a query"):
            self.run_fake([self.message(executed=True, tail=9, columns=("a",), cells=(2,), varints=(1,), last=True), None])

    def test_a_server_that_never_answers_is_unavailable(self) -> None:
        with self.assertRaises(self.common._RpcUnavailable):
            self.run_fake([None])

    def strings(self, value):
        c = self.common
        batch = c._pb_bytes(1, bytes([4])) + c._pb_bytes(5, (value + "\0").encode()) + c._pb_uint(6, 1)
        result = c._pb_bytes(1, b"s") + c._pb_bytes(3, batch) + c._pb_uint(5, 1)
        statement = c._pb_bytes(1, result) + c._pb_uint(2, 9) + c._pb_uint(3, 1)
        return c._pb_bytes(1, c._pb_uint(1, 1) + c._pb_uint(3, 20) + c._pb_bytes(219, statement)).hex()

    def test_output_limits_cover_the_wire_rendered_csv_and_stderr(self) -> None:
        with self.assertRaisesRegex(self.common.QueryError, "output limit"):
            self.run_fake([self.strings("x" * 5000)], max_output_bytes=1000)
        # Doubling quotes makes the CSV larger than the wire bytes.
        with self.assertRaisesRegex(self.common.QueryError, "output limit"):
            self.run_fake([self.strings('"' * 700), self.message(executed=False, last=True)], max_output_bytes=1200)
        with self.assertRaisesRegex(self.common.QueryError, "output limit"):
            self.run_fake(["stderr:200000"], max_output_bytes=1000, timeout=5)

    def test_a_closed_stdout_cannot_outlive_the_deadline(self) -> None:
        started = time.monotonic()
        with self.assertRaisesRegex(self.common.QueryError, "timed out"):
            self.run_fake(["closeout"], timeout=1.0)
        self.assertLess(time.monotonic() - started, 5)

    def test_an_expired_deadline_wins_over_a_buffered_frame(self) -> None:
        with self.assertRaisesRegex(self.common.QueryError, "timed out"):
            self.run_fake([self.message(executed=False, last=True)], deadline=time.monotonic() - 1)

    def test_malformed_responses_are_query_errors(self) -> None:
        c = self.common
        no_value = c._pb_bytes(1, bytes([2]))
        result = c._pb_bytes(1, b"a") + c._pb_bytes(3, no_value + c._pb_uint(6, 1)) + c._pb_uint(5, 1)
        statement = c._pb_bytes(1, result) + c._pb_uint(2, 9) + c._pb_uint(3, 1)
        missing = c._pb_bytes(1, c._pb_uint(1, 1) + c._pb_uint(3, 20) + c._pb_bytes(219, statement)).hex()
        with self.assertRaisesRegex(c.QueryError, "a cell has no value"):
            self.run_fake([missing])
        with self.assertRaisesRegex(c.QueryError, "malformed"):
            list(c._pb_fields(b"\x0a\x05ab"))
        # A statement result sent as a varint instead of a message.
        wrong = c._pb_bytes(1, c._pb_uint(1, 1) + c._pb_uint(3, 20) + c._pb_uint(219, 7)).hex()
        with self.assertRaisesRegex(c.QueryError, "field 219 has wire type 0"):
            self.run_fake([wrong])

    def test_an_interrupted_kill_never_signals_the_group_twice(self) -> None:
        import sys
        from unittest import mock

        with tempfile.TemporaryDirectory() as temporary:
            trace = Path(temporary) / "trace"
            trace.write_bytes(b"")
            real_popen = self.common.subprocess.Popen
            with mock.patch.object(
                self.common.subprocess, "Popen",
                side_effect=lambda _command, **kwargs: real_popen((sys.executable, "-c", "import time; time.sleep(60)"), **kwargs),
            ):
                rpc = self.common._TraceProcessorRpc(Path("unused"), trace)
            real_wait = rpc._process.wait
            calls = []

            def interrupted_wait(*args, **kwargs):
                if not calls:
                    calls.append("interrupted")
                    real_wait(*args, **kwargs)
                    raise KeyboardInterrupt
                calls.append("wait")
                return real_wait(*args, **kwargs)

            with mock.patch.object(self.common.os, "killpg", wraps=self.common.os.killpg) as killpg, mock.patch.object(
                rpc._process, "wait", side_effect=interrupted_wait,
            ):
                with self.assertRaises(KeyboardInterrupt):
                    rpc.kill()
                rpc.kill()
            self.assertEqual(killpg.call_count, 1)
            self.assertEqual(calls, ["interrupted", "wait"])

    def test_a_failed_start_leaves_no_process_behind(self) -> None:
        import sys
        from unittest import mock

        with tempfile.TemporaryDirectory() as temporary:
            trace = Path(temporary) / "trace"
            trace.write_bytes(b"")
            real_popen = self.common.subprocess.Popen
            started = []

            def popen(_command, **kwargs):
                started.append(real_popen((sys.executable, "-c", "import time; time.sleep(60)"), **kwargs))
                return started[-1]

            with mock.patch.object(self.common.subprocess, "Popen", side_effect=popen), mock.patch.object(
                self.common.threading.Thread, "start", side_effect=RuntimeError("no threads"),
            ):
                with self.assertRaisesRegex(RuntimeError, "no threads"):
                    self.common._TraceProcessorRpc(Path("unused"), trace)
            self.assertEqual(len(started), 1)
            self.assertIsNotNone(started[0].poll())

    def test_the_deadline_covers_a_silent_server(self) -> None:
        with self.assertRaisesRegex(self.common.QueryError, "timed out"):
            self.run_fake(["hang"], timeout=0.5)


class SessionFallbackTest(unittest.TestCase):
    def setUp(self) -> None:
        self.common = load_skill_script("_common")

    def test_processor_without_stdio_rpc_runs_queries_through_the_cli(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "trace_processor_shell"
            binary.write_text(
                "#!/usr/bin/env python3\n"
                "import sys\n"
                "if sys.argv[1] != 'query':\n"
                "    sys.exit(2)\n"
                "print('\"value\"')\n"
                "print(1)\n",
                encoding="utf-8",
            )
            binary.chmod(0o755)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            results = [self.common.run_query(trace, sql="SELECT 1 AS value;", trace_processor=str(binary))]
            with self.common.trace_processor_session(trace, trace_processor=str(binary)) as session:
                results += [
                    self.common.run_query(trace, sql="SELECT 1 AS value;", trace_processor=str(binary))
                    for _ in range(2)
                ]
                self.assertTrue(session.unavailable)
                self.assertEqual(session.start_count, 0)
            for result in results:
                self.assertEqual(result.command[1], "query")
                self.assertEqual(self.common.parse_csv_output(result.stdout), [{"value": 1}])


if __name__ == "__main__":
    unittest.main()

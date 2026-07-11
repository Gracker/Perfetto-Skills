import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tests.support import SCRIPTS, load_skill_script


def make_fake_trace_processor(path: Path) -> None:
    path.write_text(
        "#!/usr/bin/env python3\n"
        "from pathlib import Path\n"
        "import sys\n"
        "query = Path(sys.argv[sys.argv.index('--query-file') + 1]).read_text()\n"
        "if \"'trace_bounds'\" in query:\n"
        "    print('\\\"section\\\",\\\"key\\\",\\\"value\\\",\\\"encoding\\\"')\n"
        "    print('\\\"trace_bounds\\\",\\\"start_ns\\\",100,\\\"plain\\\"')\n"
        "    print('\\\"trace_bounds\\\",\\\"end_ns\\\",900,\\\"plain\\\"')\n"
        "    print('\\\"metadata\\\",\\\"android_sdk_version\\\",\\\"hex:3335\\\",\\\"hex\\\"')\n"
        "    print('\\\"table\\\",\\\"slice\\\",\\\"table\\\",\\\"plain\\\"')\n"
        "    print('\\\"table\\\",\\\"thread_state\\\",\\\"table\\\",\\\"plain\\\"')\n"
        "else:\n"
        "    print('\\\"one\\\",\\\"name\\\"')\n"
        "    print('1,\\\"value\\\"')\n",
        encoding="utf-8",
    )
    path.chmod(0o755)


class QueryProbeCliTest(unittest.TestCase):
    def setUp(self) -> None:
        for name in ("perfetto_query", "perfetto_probe"):
            self.assertTrue((SCRIPTS / f"{name}.py").is_file(), f"scripts/{name}.py")
        self.query = load_skill_script("perfetto_query")
        self.probe = load_skill_script("perfetto_probe")

    def test_probe_sql_hex_encodes_free_text_metadata(self) -> None:
        self.assertIn("hex(CAST", self.probe.PROBE_SQL)

    def test_query_cli_writes_json_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / "trace_processor_shell"
            make_fake_trace_processor(binary)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            output = root / "result.json"

            exit_code = self.query.main(
                [
                    str(trace),
                    "--sql",
                    "SELECT 1;",
                    "--trace-processor",
                    str(binary),
                    "--format",
                    "json",
                    "--output",
                    str(output),
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertEqual(
                json.loads(output.read_text(encoding="utf-8")),
                [{"name": "value", "one": 1}],
            )

    def test_query_cli_renders_public_parameters_and_modules(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            captured: dict[str, object] = {}
            output = root / "result.json"

            def fake_run_query(*args: object, **kwargs: object) -> object:
                captured.update(kwargs)
                return type("Result", (), {"stdout": '"value"\n1\n', "stderr": ""})()

            with mock.patch.object(self.query, "run_query", side_effect=fake_run_query):
                exit_code = self.query.main(
                    [
                        str(trace),
                        "--sql",
                        "SELECT ${start_ts} AS value WHERE '${package}' != ''",
                        "--param",
                        "start_ts=123",
                        "--param",
                        'package="com.example"',
                        "--module",
                        "android.startup.startups",
                        "--output",
                        str(output),
                    ]
                )
            self.assertEqual(exit_code, 0)
            self.assertIn(
                "INCLUDE PERFETTO MODULE android.startup.startups;",
                captured["sql"],
            )
            self.assertIn("SELECT 123 AS value", captured["sql"])
            self.assertIn("'com.example'", captured["sql"])

    def test_query_cli_binds_prior_json_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            prior = root / "prior.json"
            prior.write_text('[{"value": 7}]', encoding="utf-8")
            captured: dict[str, object] = {}
            output = root / "result.json"

            def fake_run_query(*args: object, **kwargs: object) -> object:
                captured.update(kwargs)
                return type("Result", (), {"stdout": '"value"\n7\n', "stderr": ""})()

            with mock.patch.object(self.query, "run_query", side_effect=fake_run_query):
                exit_code = self.query.main(
                    [
                        str(trace),
                        "--sql",
                        "SELECT value, ${prior.data[0].value} AS scalar "
                        "FROM ${prior}",
                        "--result",
                        f"prior={prior}",
                        "--output",
                        str(output),
                    ]
                )
            self.assertEqual(exit_code, 0)
            self.assertIn('SELECT 7 AS "value"', captured["sql"])
            self.assertIn("SELECT value, 7 AS scalar", captured["sql"])

    def test_probe_cli_records_identity_bounds_and_capabilities(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / "trace_processor_shell"
            make_fake_trace_processor(binary)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            output = root / "probe.json"

            exit_code = self.probe.main(
                [
                    str(trace),
                    "--trace-processor",
                    str(binary),
                    "--output",
                    str(output),
                ]
            )

            self.assertEqual(exit_code, 0)
            result = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(result["trace"]["start_ns"], 100)
            self.assertEqual(result["trace"]["end_ns"], 900)
            self.assertEqual(len(result["trace"]["sha256"]), 64)
            self.assertEqual(result["metadata"]["android_sdk_version"], 35)
            self.assertTrue(result["capabilities"]["slices"])
            self.assertTrue(result["capabilities"]["thread_states"])
            self.assertEqual(result["errors"], [])


if __name__ == "__main__":
    unittest.main()

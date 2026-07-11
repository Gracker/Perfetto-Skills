from pathlib import Path
import tempfile
import unittest

from tests.support import SCRIPTS, load_skill_script


class RuntimeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue((SCRIPTS / "_common.py").is_file(), "scripts/_common.py")
        self.common = load_skill_script("_common")

    def test_explicit_binary_wins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / "trace_processor_shell"
            binary.write_bytes(b"binary")
            binary.chmod(0o755)
            resolved = self.common.resolve_trace_processor(
                str(binary),
                env={},
                path_lookup=lambda _: None,
                cache_binary=Path(tmp) / "missing",
            )
            self.assertEqual(resolved, binary.resolve())

    def test_missing_binary_has_bootstrap_instruction(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(FileNotFoundError, "bootstrap_trace_processor.py"):
                self.common.resolve_trace_processor(
                    None,
                    env={},
                    path_lookup=lambda _: None,
                    cache_binary=Path(tmp) / "missing",
                )

    def test_query_uses_argument_array_and_parses_csv(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / "trace processor with spaces"
            binary.write_text(
                "#!/usr/bin/env python3\n"
                "import sys\n"
                "print('\\\"one\\\",\\\"missing\\\",\\\"ratio\\\"')\n"
                "print('1,\\\"[NULL]\\\",2.5')\n"
                "print('diagnostic', file=sys.stderr)\n",
                encoding="utf-8",
            )
            binary.chmod(0o755)
            trace = root / "trace with spaces.pftrace"
            trace.write_bytes(b"trace")

            result = self.common.run_query(
                trace,
                sql="SELECT 1;",
                trace_processor=str(binary),
                timeout=5,
            )

            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.command[0], str(binary.resolve()))
            self.assertIn(str(trace.resolve()), result.command)
            self.assertEqual(
                self.common.parse_csv_output(result.stdout),
                [{"one": 1, "missing": None, "ratio": 2.5}],
            )

    def test_malformed_perfetto_csv_is_rejected(self) -> None:
        malformed = (
            '"section","key","value"\n'
            '"metadata","config","name: "android"\n'
            'next line"\n'
        )
        with self.assertRaisesRegex(self.common.QueryError, "non-tabular text"):
            self.common.parse_csv_output(malformed)

    def test_csv_parser_ignores_trace_processor_leading_blank_lines(self) -> None:
        output = '\n\n"startup_id","package"\n1,"com.example"\n'
        self.assertEqual(
            self.common.parse_csv_output(output),
            [{"startup_id": 1, "package": "com.example"}],
        )

    def test_sql_template_binds_scalars_and_defaults_without_injection(self) -> None:
        rendered = self.common.render_sql_template(
            "WHERE name GLOB '${package}*' AND ts >= ${start_ts} LIMIT ${top_n|30}",
            {"package": "o'hare", "start_ts": 123},
            {},
        )
        self.assertEqual(
            rendered,
            "WHERE name GLOB 'o''hare*' AND ts >= 123 LIMIT 30",
        )

    def test_sql_template_binds_saved_result_as_relation(self) -> None:
        rendered = self.common.render_sql_template(
            "SELECT value FROM ${prior_result}",
            {},
            {"prior_result": [{"value": 1}, {"value": 2}]},
        )
        self.assertIn("SELECT 1 AS \"value\"", rendered)
        self.assertIn("UNION ALL", rendered)

    def test_sql_template_resolves_composite_result_field_paths(self) -> None:
        rendered = self.common.render_sql_template(
            "SELECT '${target_process.data[0].process_name}' AS name, "
            "${target_process.data[0].upid} AS upid",
            {},
            {"target_process": [{"process_name": "o'hare", "upid": 42}]},
        )
        self.assertEqual(
            rendered,
            "SELECT 'o''hare' AS name, 42 AS upid",
        )

    def test_sql_template_binds_json_array_for_in_clause(self) -> None:
        rendered = self.common.render_sql_template(
            "SELECT * FROM cpu WHERE ('${cpu_ids|}' = '' "
            "OR cpu IN (${cpu_ids|}))",
            {"cpu_ids": [4, 5, 6, 7]},
            {},
        )
        self.assertEqual(
            rendered,
            "SELECT * FROM cpu WHERE ('4,5,6,7' = '' "
            "OR cpu IN (4, 5, 6, 7))",
        )

        empty = self.common.render_sql_template(
            "SELECT * FROM cpu WHERE ('${cpu_ids|}' = '' "
            "OR cpu IN (${cpu_ids|}))",
            {"cpu_ids": []},
            {},
        )
        self.assertEqual(
            empty,
            "SELECT * FROM cpu WHERE ('' = '' OR cpu IN (NULL))",
        )

    def test_sql_template_rejects_missing_parameter(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing SQL template value"):
            self.common.render_sql_template("SELECT ${missing}", {}, {})

    def test_query_output_is_bounded_before_loading_into_memory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "trace_processor_shell"
            binary.write_text(
                "#!/usr/bin/env python3\nprint('x' * 10000)\n",
                encoding="utf-8",
            )
            binary.chmod(0o755)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            with self.assertRaisesRegex(self.common.QueryError, "output limit"):
                self.common.run_query(
                    trace,
                    sql="SELECT 1",
                    trace_processor=str(binary),
                    max_output_bytes=100,
                )


if __name__ == "__main__":
    unittest.main()

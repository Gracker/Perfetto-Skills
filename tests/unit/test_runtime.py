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


if __name__ == "__main__":
    unittest.main()

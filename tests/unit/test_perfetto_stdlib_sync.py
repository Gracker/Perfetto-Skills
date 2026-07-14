from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.sync_perfetto_stdlib import build_stdlib_index, compare_stdlib


class PerfettoStdlibSyncTest(unittest.TestCase):
    def test_indexes_modules_symbols_and_intrinsic_substrate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            subprocess.run(["git", "init", "-q", repo], check=True)
            subprocess.run(["git", "-C", repo, "config", "user.email", "test@example.com"], check=True)
            subprocess.run(["git", "-C", repo, "config", "user.name", "Test"], check=True)
            sql = repo / "src/trace_processor/perfetto_sql/stdlib/android/example.sql"
            sql.parent.mkdir(parents=True)
            sql.write_text(
                "-- Example module\nCREATE PERFETTO TABLE android_example AS SELECT 1;\n"
                "CREATE PERFETTO FUNCTION android_fn(x LONG) RETURNS LONG AS SELECT $x;\n",
                encoding="utf-8",
            )
            schema = repo / "src/trace_processor/tables/example_tables.py"
            schema.parent.mkdir(parents=True)
            schema.write_text("class ExampleTable: pass\n", encoding="utf-8")
            subprocess.run(["git", "-C", repo, "add", "."], check=True)
            subprocess.run(["git", "-C", repo, "commit", "-qm", "stdlib"], check=True)
            revision = subprocess.run(
                ["git", "-C", repo, "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            index = build_stdlib_index(repo, revision)
            self.assertEqual(index["modules"][0]["module"], "android.example")
            self.assertEqual(
                {symbol["kind"] for symbol in index["modules"][0]["symbols"]},
                {"TABLE", "FUNCTION"},
            )
            self.assertEqual(len(index["intrinsic_schema_sources"]), 1)

    def test_compare_reports_module_drift(self) -> None:
        old = {"modules": [{"module": "a", "sha256": "1"}, {"module": "b", "sha256": "1"}]}
        new = {"modules": [{"module": "b", "sha256": "2"}, {"module": "c", "sha256": "1"}]}
        self.assertEqual(
            compare_stdlib(old, new),
            {"added": ["c"], "removed": ["a"], "changed": ["b"]},
        )


if __name__ == "__main__":
    unittest.main()

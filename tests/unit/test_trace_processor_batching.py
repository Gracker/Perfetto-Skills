"""Every trace_processor_shell invocation re-parses the whole trace.

These tests pin how many invocations the schema and capability checks cost, so
a per-table loop cannot quietly return: on a 19 MB trace one invocation takes
about two seconds, and one manifest query used to spend sixteen of them.
"""

from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest import mock

from tests.support import load_skill_script


TRACE = Path("fixture.trace")
LIMITS = {"trace_processor": None, "timeout": 1, "max_output_bytes": 4096}


def completed(stdout: str = "") -> SimpleNamespace:
    return SimpleNamespace(stdout=stdout, stderr="", returncode=0)


class TraceProcessorBatchingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.probe = load_skill_script("perfetto_probe")
        self.query = load_skill_script("perfetto_query")
        self.common = sys.modules["_common"]

    def probe_counts(self, run_query: mock.Mock) -> dict[str, int]:
        with mock.patch.object(self.probe, "run_query", run_query), mock.patch.object(
            self.probe,
            "build_probe",
            side_effect=lambda _trace, _rows, *, row_counts: row_counts,
        ):
            return self.probe.probe_trace(TRACE, **LIMITS)

    @staticmethod
    def probe_csv(tables: list[str]) -> str:
        return "section,key,value,encoding\n" + "".join(
            f"table,{table},table,plain\n" for table in tables
        )

    def test_probe_counts_every_capability_table_in_one_invocation(self) -> None:
        tables = sorted(set().union(*self.probe.CAPABILITY_TABLES.values()))
        counts = "table_name,row_count\n" + "".join(
            f"{table},{index}\n" for index, table in enumerate(tables)
        )
        run_query = mock.Mock(
            side_effect=[completed(self.probe_csv(tables)), completed(counts)]
        )

        row_counts = self.probe_counts(run_query)

        self.assertEqual(run_query.call_count, 2)
        self.assertEqual(row_counts, {table: index for index, table in enumerate(tables)})

    def test_probe_names_unreadable_tables_by_falling_back_to_single_counts(self) -> None:
        def fake_run_query(_trace: Path, *, sql: str, **_kwargs: object) -> object:
            if sql == self.probe.PROBE_SQL:
                return completed(self.probe_csv(["sched", "slice"]))
            if '"sched"' in sql:  # the batch and the single sched count
                raise RuntimeError("no such table: sched")
            return completed("table_name,row_count\nslice,7\n")

        run_query = mock.Mock(side_effect=fake_run_query)

        row_counts = self.probe_counts(run_query)

        self.assertEqual(row_counts, {"slice": 7})
        self.assertEqual(run_query.call_count, 4)

    def test_manifest_schema_checks_modules_and_tables_in_one_invocation(self) -> None:
        entry = {
            "sql_dependencies": {
                "declared_modules": ["android.startup.startups"],
                "required_tables": ["android_startups", "slice"],
            }
        }
        run_query = mock.Mock(return_value=completed())
        with mock.patch.object(self.query, "run_query", run_query):
            verified = self.query.verify_manifest_schema(entry, TRACE, **LIMITS)

        run_query.assert_called_once()
        sql = run_query.call_args.kwargs["sql"]
        self.assertTrue(sql.startswith("INCLUDE PERFETTO MODULE android.startup.startups;"))
        self.assertIn('SELECT * FROM "android_startups" LIMIT 0;', sql)
        self.assertIn('SELECT * FROM "slice" LIMIT 0;', sql)
        self.assertEqual(verified, {"android_startups", "slice"})

    def test_manifest_schema_failure_still_fails_the_query(self) -> None:
        entry = {"sql_dependencies": {"declared_modules": [], "required_tables": ["a", "b"]}}
        run_query = mock.Mock(side_effect=RuntimeError("no such table: b"))
        with mock.patch.object(self.query, "run_query", run_query):
            with self.assertRaisesRegex(RuntimeError, "no such table: b"):
                self.query.verify_manifest_schema(entry, TRACE, **LIMITS)
        run_query.assert_called_once()

    def test_missing_tables_costs_one_invocation_when_every_table_is_readable(self) -> None:
        run_query = mock.Mock(return_value=completed())
        with mock.patch.object(self.common, "run_query", run_query):
            missing = self.common.missing_tables(
                TRACE, ["a", "b", "c"], modules=["m"], **LIMITS
            )

        self.assertEqual(missing, [])
        run_query.assert_called_once()

    def test_missing_tables_names_each_unreadable_table(self) -> None:
        def fake_run_query(_trace: Path, *, sql: str, **_kwargs: object) -> object:
            self.assertTrue(sql.startswith("INCLUDE PERFETTO MODULE m;"))
            if '"b"' in sql:
                raise RuntimeError("no such table: b")
            return completed()

        run_query = mock.Mock(side_effect=fake_run_query)
        with mock.patch.object(self.common, "run_query", run_query):
            missing = self.common.missing_tables(
                TRACE, ["a", "b", "c"], modules=["m"], **LIMITS
            )

        self.assertEqual(missing, ["b"])
        self.assertEqual(run_query.call_count, 4)

    def test_missing_tables_without_tables_runs_nothing(self) -> None:
        run_query = mock.Mock()
        with mock.patch.object(self.common, "run_query", run_query):
            self.assertEqual(self.common.missing_tables(TRACE, [], **LIMITS), [])
        run_query.assert_not_called()


if __name__ == "__main__":
    unittest.main()

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

from tests.support import (
    SCRIPTS,
    fixture_path,
    fixture_root,
    run_commands_concurrently,
    trace_processor,
)
from tools.validate_all_queries import assert_rows


ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(fixture_root(), "PERFETTO_FIXTURE_ROOT not configured")
class FixtureManifestTest(unittest.TestCase):
    def test_all_declared_semantic_assertions_execute_on_their_hashed_fixture(self) -> None:
        manifest = json.loads((ROOT / "fixtures/manifest.json").read_text(encoding="utf-8"))
        executed = 0
        with tempfile.TemporaryDirectory() as temporary:
            jobs = []
            commands = []
            for fixture in manifest["fixtures"]:
                if not fixture.get("assertions"):
                    continue
                try:
                    trace = fixture_path(fixture["id"])
                except FileNotFoundError:
                    if os.environ.get("PERFETTO_FIXTURE_TIER") == "offline":
                        continue
                    raise
                for assertion_index, assertion in enumerate(fixture["assertions"]):
                    output = Path(temporary) / f"{fixture['id']}-{assertion_index}.json"
                    command = [
                        sys.executable,
                        str(SCRIPTS / "perfetto_query.py"),
                        str(trace),
                        "--query-id",
                        assertion["query_id"],
                        "--trace-processor",
                        trace_processor(),
                        "--output",
                        str(output),
                    ]
                    for name, value in sorted(assertion.get("params", {}).items()):
                        command.extend(("--param", f"{name}={json.dumps(value)}"))
                    jobs.append((fixture, assertion, output))
                    commands.append(command)
            # Each query is an independent trace_processor process, so they run
            # concurrently; results are still asserted in manifest order.
            completions = run_commands_concurrently(commands)
            for (fixture, assertion, output), completed in zip(jobs, completions):
                with self.subTest(fixture=fixture["id"], query=assertion["query_id"]):
                    self.assertEqual(completed.returncode, 0, completed.stderr)
                    rows = json.loads(output.read_text(encoding="utf-8"))
                    assert_rows(rows, assertion)
                    executed += 1
        offline = os.environ.get("PERFETTO_FIXTURE_TIER") == "offline"
        expected = sum(
            len(fixture.get("assertions", []))
            for fixture in manifest["fixtures"]
            if not offline or fixture["id"] == "startup-api32-warm-smoke"
        )
        self.assertGreater(expected, 0)
        self.assertEqual(executed, expected)


class FixtureAssertionSemanticsTest(unittest.TestCase):
    def test_non_empty_assertion_rejects_null_and_empty_string(self) -> None:
        assertion = {"kind": "non_empty", "field": "value"}
        for value in (None, ""):
            with self.subTest(value=value):
                with self.assertRaises(AssertionError):
                    assert_rows([{"value": value}], assertion)


if __name__ == "__main__":
    unittest.main()

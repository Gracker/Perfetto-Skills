import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.support import SCRIPTS, trace_processor


SOURCE = Path(os.environ["SMARTPERFETTO_SOURCE"]) if os.environ.get("SMARTPERFETTO_SOURCE") else None
RUNTIME = (
    Path(__file__).resolve().parents[2]
    / "skills"
    / "perfetto-performance-analysis"
    / "references"
    / "generated"
    / "runtime"
)


def assert_semantic_assertion(
    testcase: unittest.TestCase,
    rows: list[dict[str, object]],
    assertion: dict[str, object],
) -> None:
    testcase.assertTrue(rows, assertion)
    field = assertion.get("field")
    if assertion["kind"] == "field_equals":
        testcase.assertEqual(rows[0].get(field), assertion["value"])
    elif assertion["kind"] == "field_positive":
        testcase.assertGreater(rows[0].get(field, 0), 0)
    elif assertion["kind"] == "non_empty":
        testcase.assertIn(field, rows[0])
        testcase.assertNotIn(rows[0][field], (None, "", [], {}))
    else:
        testcase.fail(f"unknown assertion kind: {assertion['kind']}")


@unittest.skipUnless(SOURCE and SOURCE.is_dir(), "SMARTPERFETTO_SOURCE not configured")
class FixtureManifestTest(unittest.TestCase):
    def test_all_declared_semantic_assertions_execute_on_their_hashed_fixture(self) -> None:
        manifest = json.loads((RUNTIME / "fixture-manifest.json").read_text(encoding="utf-8"))
        executed = 0
        with tempfile.TemporaryDirectory() as temporary:
            for fixture in manifest["fixtures"]:
                if not fixture.get("assertions"):
                    continue
                trace = SOURCE / fixture["source"]
                self.assertTrue(trace.is_file(), fixture["id"])
                self.assertEqual(
                    hashlib.sha256(trace.read_bytes()).hexdigest(),
                    fixture["sha256"],
                    fixture["id"],
                )
                for assertion_index, assertion in enumerate(fixture["assertions"]):
                    with self.subTest(fixture=fixture["id"], query=assertion["query_id"]):
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
                        completed = subprocess.run(
                            command,
                            check=False,
                            capture_output=True,
                            text=True,
                        )
                        self.assertEqual(completed.returncode, 0, completed.stderr)
                        rows = json.loads(output.read_text(encoding="utf-8"))
                        assert_semantic_assertion(self, rows, assertion)
                        executed += 1
        self.assertEqual(executed, 9)


class FixtureAssertionSemanticsTest(unittest.TestCase):
    def test_non_empty_assertion_rejects_null_and_empty_string(self) -> None:
        assertion = {"kind": "non_empty", "field": "value"}
        for value in (None, ""):
            with self.subTest(value=value):
                with self.assertRaises(AssertionError):
                    assert_semantic_assertion(self, [{"value": value}], assertion)


if __name__ == "__main__":
    unittest.main()

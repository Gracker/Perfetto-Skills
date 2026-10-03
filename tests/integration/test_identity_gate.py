"""The identity gate on a real trace decides as SmartPerfetto does."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.support import ROOT, SCRIPTS


TRACE = ROOT / "fixtures/smoke/api32_startup_warm.perfetto-trace"
WINDOW = ["--param", "start_ts=157479316678737", "--param", "end_ts=157481465920686"]


@unittest.skipUnless(os.environ.get("PERFETTO_TRACE_PROCESSOR"), "trace processor not configured")
class IdentityGateRealTraceTest(unittest.TestCase):
    def run_skill(self, skill: str, *params: str) -> dict:
        with tempfile.TemporaryDirectory() as temporary:
            completed = subprocess.run(
                [sys.executable, str(SCRIPTS / "perfetto_skill.py"), "run", str(TRACE), "--skill", skill,
                 "--trace-processor", os.environ["PERFETTO_TRACE_PROCESSOR"], "--output-dir", temporary, *params],
                capture_output=True, text=True, check=False,
            )
            return json.loads((Path(temporary) / "result.json").read_text(encoding="utf-8"))

    def test_a_package_sharing_its_uid_is_refused_with_smartperfetto_reason(self) -> None:
        # SmartPerfetto refuses com.google.android.gms.persistent on this trace:
        # com.google.android.gms shares its UID and scores as a close candidate.
        result = self.run_skill("network_analysis", *WINDOW, "--param", 'package="com.google.android.gms.persistent"')
        self.assertEqual(result["status"], "identity_blocked")
        self.assertEqual(
            result["error"],
            'Process identity could not be verified for skill "network_analysis": status=ambiguous, confidence=100',
        )
        self.assertEqual(result["identity"]["gate_status"], "ambiguous")
        self.assertEqual(result["steps"], [])

    def test_the_public_cli_hands_an_undeclared_alias_to_the_gate(self) -> None:
        # network_analysis declares only `package`; `processName` is a gate selector.
        result = self.run_skill("network_analysis", *WINDOW, "--param", 'processName="com.google.android.gms.persistent"')
        self.assertEqual(result["status"], "identity_blocked")
        self.assertIn("status=ambiguous, confidence=100", result["error"])

    def test_a_skill_without_a_name_runs_unscoped(self) -> None:
        result = self.run_skill("network_analysis", *WINDOW)
        self.assertNotEqual(result["status"], "identity_blocked")
        self.assertEqual(result["identity"]["status"], "not_requested")

    def test_a_verified_upid_or_pid_scopes_the_run_exactly(self) -> None:
        # SmartPerfetto runs main_thread_states_in_range under exact UPID 595
        # for either selector; the evidence names the applied scope.
        for selector in ("upid=595", "pid=5292"):
            with self.subTest(selector=selector):
                result = self.run_skill("main_thread_states_in_range", *WINDOW, "--param", selector)
                self.assertEqual(result["status"], "completed", result.get("error"))
                self.assertEqual(result["params"]["upid"], 595)
                evidence = result["evidence"][0]
                self.assertEqual(evidence["evidence_role"], "target")
                self.assertEqual(
                    {key: evidence["applied_process_scope"][key] for key in ("mode", "upid", "trace_side")},
                    {"mode": "exact_upid", "upid": 595, "trace_side": "trace_a"},
                )

    def test_an_exact_scope_is_refused_for_sql_without_a_process_scope(self) -> None:
        result = self.run_skill("network_analysis", "--param", "upid=595")
        self.assertEqual(result["status"], "identity_blocked")
        self.assertTrue(result["error"].startswith(
            "Exact UPID scope is unsupported: network_analysis.check_network_data: "
            "SQL has no process_scope declaration. Use a supported exact Skill: "
        ), result["error"])
        self.assertEqual(result["steps"], [])

    def test_an_unknown_upid_is_never_replaced(self) -> None:
        result = self.run_skill("main_thread_states_in_range", *WINDOW, "--param", "upid=647")
        self.assertEqual(result["status"], "identity_blocked")
        self.assertEqual(result["error"], "Explicit UPID could not be verified; no other process may replace it")

    def test_a_query_declared_unavailable_under_an_exact_scope_still_writes_its_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "rows.json"
            completed = subprocess.run(
                [sys.executable, str(SCRIPTS / "perfetto_query.py"), str(TRACE),
                 "--query-id", "scrolling_analysis/buffer_tx_performance_fallback", "--param", "upid=595",
                 "--trace-processor", os.environ["PERFETTO_TRACE_PROCESSOR"], "--output", str(output), "--format", "json"],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(completed.returncode, 2)
            self.assertIn("error: exact_scope_unavailable: BufferTX track names", completed.stderr)
            evidence = json.loads(output.with_suffix(".json.evidence.json").read_text(encoding="utf-8"))
        self.assertEqual((evidence["status"], evidence["code"], evidence["partial"]), ("unavailable", "exact_scope_unavailable", True))
        self.assertIsNone(evidence["capability_gate"])  # decided before any schema or capability work
        self.assertIsNone(evidence["query"]["rendered_sha256"])
        self.assertEqual(evidence["scope_limitations"], [evidence["error"]])
        self.assertNotIn("applied_process_scope", evidence)
        entry = evidence["scope_provenance"]["entries"][0]
        self.assertEqual((entry["availability"], entry["scope"]["upid"]), ("unavailable", 595))

    def test_an_exact_query_records_the_variant_that_ran(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "rows.json"
            completed = subprocess.run(
                [sys.executable, str(SCRIPTS / "perfetto_query.py"), str(TRACE),
                 "--query-id", "scrolling_analysis/buffer_tx_coverage_probe", "--param", "upid=595", *WINDOW,
                 "--trace-processor", os.environ["PERFETTO_TRACE_PROCESSOR"], "--output", str(output), "--format", "json"],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            evidence = json.loads(output.with_suffix(".json.evidence.json").read_text(encoding="utf-8"))
        shard = json.loads((SCRIPTS.parent / "references/generated/runtime/queries/scrolling_analysis.json").read_text(encoding="utf-8"))
        variant = next(query for query in shard["queries"] if query["id"] == "scrolling_analysis/buffer_tx_coverage_probe.exact")
        self.assertEqual(evidence["query"]["id"], "scrolling_analysis/buffer_tx_coverage_probe")
        self.assertEqual(evidence["query"]["executed_id"], variant["id"])
        self.assertEqual(evidence["query"]["source_sha256"], variant["sha256"])
        self.assertEqual(evidence["applied_process_scope"]["upid"], 595)


if __name__ == "__main__":
    unittest.main()

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


if __name__ == "__main__":
    unittest.main()

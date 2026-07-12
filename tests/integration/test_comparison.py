import json
import os
from pathlib import Path
import tempfile
import unittest

from tests.support import run_public_compare, run_public_probe, run_public_query


TRACE_ROOT = Path(os.environ["SMARTPERFETTO_TEST_TRACES"]) if os.environ.get("SMARTPERFETTO_TEST_TRACES") else None


@unittest.skipUnless(
    TRACE_ROOT and TRACE_ROOT.is_dir(),
    "SMARTPERFETTO_TEST_TRACES not configured",
)
class ComparisonTest(unittest.TestCase):
    def test_startup_traces_remain_independent_before_delta(self) -> None:
        traces = [TRACE_ROOT / "launch_light.pftrace", TRACE_ROOT / "lacunh_heavy.pftrace"]
        self.assertTrue(all(trace.is_file() for trace in traces))
        sides = []
        for label, trace in zip(("baseline", "candidate"), traces, strict=True):
            probe = run_public_probe(trace)
            self.assertEqual(probe["status"], "ok", probe)
            counts = run_public_query(
                trace,
                sql="SELECT COUNT(*) AS slice_count FROM slice",
            )
            self.assertEqual(counts["status"], "ok", counts)
            sides.append(
                {
                    "trace_side": label,
                    "sha256": probe["trace"]["sha256"],
                    "start_ns": probe["trace"]["start_ns"],
                    "end_ns": probe["trace"]["end_ns"],
                    "slice_count": counts["rows"][0]["slice_count"],
                }
            )
        self.assertEqual([side["trace_side"] for side in sides], ["baseline", "candidate"])
        self.assertNotEqual(sides[0]["sha256"], sides[1]["sha256"])
        self.assertTrue(all(side["end_ns"] > side["start_ns"] for side in sides))
        self.assertTrue(all(side["slice_count"] > 0 for side in sides))
        with tempfile.TemporaryDirectory() as temporary:
            paths = []
            for side in sides:
                path = Path(temporary) / f"{side['trace_side']}.json"
                path.write_text(
                    json.dumps(
                        {
                            "schema_version": 2,
                            "trace": {
                                "sha256": side["sha256"],
                                "start_ns": side["start_ns"],
                                "end_ns": side["end_ns"],
                            },
                            "comparison_context": {
                                "identity": {"scope": "whole_trace"},
                                "window_duration_ns": side["end_ns"] - side["start_ns"],
                                "refresh_budget_ns": None,
                                "cpu_topology": "unknown",
                                "capabilities": ["slices"],
                                "android_profile": {"api": "from_trace"},
                                "processor": {"commit": "locked"},
                            },
                            "metrics": {
                                "trace.slice_count": {
                                    "status": "observed",
                                    "value": side["slice_count"],
                                    "unit": "count",
                                    "definition": "slice rows in the full trace",
                                    "source_sha256": "c" * 64,
                                    "evidence_refs": [],
                                }
                            },
                            "limitations": [],
                        }
                    ),
                    encoding="utf-8",
                )
                paths.append((side["trace_side"], path))
            comparison = run_public_compare(paths, baseline="baseline")
        self.assertEqual(comparison["status"], "partial", comparison)
        self.assertFalse(comparison["metrics"][0]["comparable"])
        self.assertIn("window_duration_ns", comparison["metrics"][0]["reason"])


if __name__ == "__main__":
    unittest.main()

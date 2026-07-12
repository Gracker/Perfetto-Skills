from pathlib import Path
import math
import tempfile
import unittest

from tests.support import load_skill_script


class CompareTest(unittest.TestCase):
    def setUp(self) -> None:
        self.compare = load_skill_script("perfetto_compare")

    def side(self, sha: str, value: float, unit: str = "ms") -> dict[str, object]:
        return {
            "schema_version": 2,
            "trace": {"sha256": sha, "start_ns": 1, "end_ns": 10},
            "comparison_context": {
                "identity": {"process_name": "com.example", "upid_scope": "target"},
                "window_duration_ns": 9,
                "refresh_budget_ns": 16666667,
                "cpu_topology": "8-core-1-3-4",
                "capabilities": ["scheduling", "frame_timeline"],
                "android_profile": {"api": 36, "oem": "AOSP"},
                "processor": {"commit": "c59f57"},
            },
            "metrics": {
                "startup.ttid": {
                    "status": "observed",
                    "value": value,
                    "unit": unit,
                    "definition": "time to initial display",
                    "source_sha256": "c" * 64,
                    "evidence_refs": ["E1"],
                }
            },
            "limitations": [],
        }

    def test_builds_file_based_delta_without_snapshot_services(self) -> None:
        result = self.compare.build_comparison(
            [
                ("baseline", Path("baseline.json"), self.side("a" * 64, 100.0)),
                ("candidate", Path("candidate.json"), self.side("b" * 64, 125.0)),
            ],
            baseline="baseline",
            metric_keys=None,
        )
        row = result["metrics"][0]
        self.assertTrue(row["comparable"])
        self.assertEqual(row["deltas"]["candidate"]["absolute"], 25.0)
        self.assertEqual(row["deltas"]["candidate"]["percent"], 25.0)
        self.assertNotIn("snapshot", str(result).lower())

    def test_unit_mismatch_is_typed_not_compared(self) -> None:
        result = self.compare.build_comparison(
            [
                ("baseline", Path("baseline.json"), self.side("a" * 64, 100.0)),
                ("candidate", Path("candidate.json"), self.side("b" * 64, 125.0, "ns")),
            ],
            baseline="baseline",
            metric_keys=None,
        )
        self.assertFalse(result["metrics"][0]["comparable"])
        self.assertIn("unit", result["metrics"][0]["reason"])

    def test_duplicate_side_labels_are_rejected(self) -> None:
        side = self.side("a" * 64, 100.0)
        with self.assertRaisesRegex(ValueError, "duplicate side"):
            self.compare.build_comparison(
                [("same", Path("a.json"), side), ("same", Path("b.json"), side)],
                baseline="same",
                metric_keys=None,
            )

    def test_identity_mismatch_blocks_metric_comparison(self) -> None:
        baseline = self.side("a" * 64, 100.0)
        candidate = self.side("b" * 64, 125.0)
        candidate["comparison_context"]["identity"]["process_name"] = "com.other"
        result = self.compare.build_comparison(
            [("baseline", Path("a.json"), baseline), ("candidate", Path("b.json"), candidate)],
            baseline="baseline",
            metric_keys=None,
        )
        self.assertFalse(result["metrics"][0]["comparable"])
        self.assertIn("identity", result["metrics"][0]["reason"])

    def test_non_finite_metric_is_rejected(self) -> None:
        for value in (math.nan, math.inf, -math.inf):
            with self.subTest(value=value):
                with self.assertRaisesRegex(ValueError, "finite"):
                    self.compare.build_comparison(
                        [
                            ("baseline", Path("a.json"), self.side("a" * 64, value)),
                            ("candidate", Path("b.json"), self.side("b" * 64, 1.0)),
                        ],
                        baseline="baseline",
                        metric_keys=None,
                    )


if __name__ == "__main__":
    unittest.main()

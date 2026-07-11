import os
from pathlib import Path
import unittest

from tests.support import generated_sql, run_public_probe, run_public_query


TRACE_ROOT = Path(os.environ["SMARTPERFETTO_TEST_TRACES"]) if os.environ.get("SMARTPERFETTO_TEST_TRACES") else None


@unittest.skipUnless(
    TRACE_ROOT and TRACE_ROOT.is_dir(),
    "SMARTPERFETTO_TEST_TRACES not configured",
)
class RealTraceTest(unittest.TestCase):
    def test_all_six_fixture_traces_are_parseable(self) -> None:
        names = (
            "launch_light.pftrace",
            "lacunh_heavy.pftrace",
            "scroll_Standard-AOSP-App-Without-PreAnimation.pftrace",
            "Scroll-Flutter-327-TextureView.pftrace",
            "Scroll-Flutter-SurfaceView-Wechat-Wenyiwen.pftrace",
            "scroll-demo-customer-scroll.pftrace",
        )
        for name in names:
            with self.subTest(trace=name):
                trace = TRACE_ROOT / name
                self.assertTrue(trace.is_file())
                probe = run_public_probe(trace)
                self.assertEqual(probe["status"], "ok", probe)
                self.assertGreater(
                    probe["trace"]["end_ns"], probe["trace"]["start_ns"]
                )

    def test_startup_probe_and_generated_query(self) -> None:
        trace = TRACE_ROOT / "launch_light.pftrace"
        self.assertTrue(trace.is_file())
        probe = run_public_probe(trace)
        self.assertEqual(probe["status"], "ok", probe)
        self.assertGreater(probe["trace"]["end_ns"], probe["trace"]["start_ns"])
        result = run_public_query(
            trace,
            sql_file=generated_sql("startup_slow_reasons", "startup_overview.sql"),
            modules=("android.startup.startups", "android.startup.time_to_display"),
        )
        self.assertEqual(result["status"], "ok", result)
        self.assertGreater(len(result["rows"]), 0, result)
        self.assertIn("startup_type", result["rows"][0])

    def test_standard_scroll_has_frame_timeline_signal(self) -> None:
        trace = TRACE_ROOT / "scroll_Standard-AOSP-App-Without-PreAnimation.pftrace"
        self.assertTrue(trace.is_file())
        result = run_public_query(
            trace,
            sql_file=generated_sql("scrolling_analysis", "frame_timeline_check.sql"),
        )
        self.assertEqual(result["status"], "ok", result)
        self.assertEqual(result["rows"][0]["has_frame_timeline"], 1)


if __name__ == "__main__":
    unittest.main()

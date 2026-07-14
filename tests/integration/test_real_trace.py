import unittest

from tests.support import (
    fixture_available,
    fixture_path,
    generated_sql,
    run_public_probe,
    run_public_query,
)


REAL_TRACE_IDS = (
    "startup-light-api36",
    "startup-heavy-api36",
    "scroll-aosp-api35",
    "flutter-texture-api35",
    "flutter-surface-api35",
    "scroll-oppo-api36",
)


@unittest.skipUnless(
    all(fixture_available(fixture_id) for fixture_id in REAL_TRACE_IDS),
    "full PERFETTO_FIXTURE_ROOT not configured",
)
class RealTraceTest(unittest.TestCase):
    def test_all_six_fixture_traces_are_parseable(self) -> None:
        for fixture_id in REAL_TRACE_IDS:
            with self.subTest(trace=fixture_id):
                trace = fixture_path(fixture_id)
                probe = run_public_probe(trace)
                self.assertEqual(probe["status"], "ok", probe)
                self.assertGreater(
                    probe["trace"]["end_ns"], probe["trace"]["start_ns"]
                )

    def test_startup_probe_and_generated_query(self) -> None:
        trace = fixture_path("startup-light-api36")
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
        trace = fixture_path("scroll-aosp-api35")
        result = run_public_query(
            trace,
            sql_file=generated_sql("scrolling_analysis", "frame_timeline_check.sql"),
        )
        self.assertEqual(result["status"], "ok", result)
        self.assertEqual(result["rows"][0]["has_frame_timeline"], 1)


if __name__ == "__main__":
    unittest.main()

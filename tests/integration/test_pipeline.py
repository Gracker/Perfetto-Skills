import unittest

from tests.support import fixture_available, fixture_path, generated_sql, run_public_query


@unittest.skipUnless(
    fixture_available("flutter-texture-api35"),
    "full PERFETTO_FIXTURE_ROOT not configured",
)
class PipelineTest(unittest.TestCase):
    def test_flutter_textureview_signals_are_observed(self) -> None:
        trace = fixture_path("flutter-texture-api35")
        result = run_public_query(
            trace,
            sql_file=generated_sql("rendering_pipeline_detection", "thread_signals.sql"),
            params={"package": "com.example.friendscircle.v27.textureview"},
        )
        self.assertEqual(result["status"], "ok", result)
        signals = result["rows"][0]
        self.assertGreater(signals["flutter_ui_count"], 0, signals)
        self.assertGreater(signals["render_thread_count"], 0, signals)
        slices = run_public_query(
            trace,
            sql_file=generated_sql("rendering_pipeline_detection", "slice_signals.sql"),
            params={"package": "com.example.friendscircle.v27.textureview"},
        )
        self.assertEqual(slices["status"], "ok", slices)
        self.assertGreater(slices["rows"][0]["texture_view_count"], 0, slices)


if __name__ == "__main__":
    unittest.main()

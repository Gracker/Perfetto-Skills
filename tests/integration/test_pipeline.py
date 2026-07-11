import os
from pathlib import Path
import unittest

from tests.support import generated_sql, run_public_query


TRACE_ROOT = Path(os.environ["SMARTPERFETTO_TEST_TRACES"]) if os.environ.get("SMARTPERFETTO_TEST_TRACES") else None


@unittest.skipUnless(
    TRACE_ROOT and TRACE_ROOT.is_dir(),
    "SMARTPERFETTO_TEST_TRACES not configured",
)
class PipelineTest(unittest.TestCase):
    def test_flutter_textureview_signals_are_observed(self) -> None:
        trace = TRACE_ROOT / "Scroll-Flutter-327-TextureView.pftrace"
        self.assertTrue(trace.is_file())
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

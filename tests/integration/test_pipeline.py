import unittest

from tests.support import fixture_available, fixture_path, generated_sql, run_public_query


@unittest.skipUnless(
    fixture_available("flutter-texture-api35"),
    "full PERFETTO_FIXTURE_ROOT not configured",
)
class PipelineTest(unittest.TestCase):
    def test_flutter_textureview_signals_are_observed(self) -> None:
        trace = fixture_path("flutter-texture-api35")
        active_processes = run_public_query(
            trace,
            sql_file=generated_sql(
                "rendering_pipeline_detection", "active_rendering_processes.sql"
            ),
            params={"package": "com.example.friendscircle.v27.textureview"},
        )
        self.assertEqual(active_processes["status"], "ok", active_processes)
        self.assertGreater(active_processes["rows"][0]["frame_count"], 0)

        bufferqueue = run_public_query(
            trace,
            sql_file=generated_sql(
                "rendering_pipeline_detection", "bufferqueue_path_signals.sql"
            ),
            params={"package": "com.example.friendscircle.v27.textureview"},
        )
        self.assertEqual(bufferqueue["status"], "ok", bufferqueue)
        self.assertGreater(bufferqueue["rows"][0]["queue_buffer_count"], 0)

        scores = run_public_query(
            trace,
            sql_file=generated_sql(
                "rendering_pipeline_detection", "score_pipelines.sql"
            ),
            params={"package": "com.example.friendscircle.v27.textureview"},
        )
        self.assertEqual(scores["status"], "ok", scores)
        flutter_texture = next(
            row
            for row in scores["rows"]
            if row["pipeline_id"] == "FLUTTER_TEXTUREVIEW"
        )
        self.assertGreater(flutter_texture["score"], 0.5, flutter_texture)
        self.assertEqual(
            max(scores["rows"], key=lambda row: row["score"])["pipeline_id"],
            "FLUTTER_TEXTUREVIEW",
        )


if __name__ == "__main__":
    unittest.main()

import unittest

from tests.support import SCRIPTS, fixture_available, fixture_path, generated_sql, load_skill_script, run_public_query


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

        # Use the production result renderer and the actual trace scores. The
        # selected teaching location must resolve inside the standalone Skill.
        common = load_skill_script("_common")
        determine = common.render_sql_template(
            generated_sql("rendering_pipeline_detection", "determine_pipeline.sql").read_text(encoding="utf-8"),
            {}, {"pipeline_scores": scores["rows"]},
        )
        selected = run_public_query(trace, sql=determine)
        self.assertEqual(selected["status"], "ok", selected)
        self.assertEqual(len(selected["rows"]), 1)
        row = selected["rows"][0]
        self.assertEqual(row["primary_pipeline_id"], "FLUTTER_TEXTUREVIEW")
        location, separator, anchor = row["doc_path"].partition("#")
        self.assertEqual(location, "references/generated/knowledge/rendering-teaching.md")
        self.assertEqual(separator, "#")
        self.assertEqual(anchor, row["primary_rendering_type_id"].lower())
        self.assertIn(f'id="{anchor}"', (SCRIPTS.parent / location).read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()

"""Buffer evidence boundaries on the public project's checksum-owned scroll trace."""

import unittest

from tests.support import fixture_available, fixture_path, generated_sql, run_public_query


FIXTURE = "scroll-aosp-api35"
PACKAGE = "com.example.wechatfriendforcustomscroller"


@unittest.skipUnless(fixture_available(FIXTURE), "full PERFETTO_FIXTURE_ROOT not configured")
class RenderingBufferEvidenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.trace = fixture_path(FIXTURE)
        bounds = run_public_query(cls.trace, sql="SELECT start_ts, end_ts FROM trace_bounds")
        if bounds["status"] != "ok" or len(bounds.get("rows", [])) != 1:
            raise AssertionError(bounds)
        cls.params = {"package": PACKAGE, **bounds["rows"][0]}

    def query(self, skill: str, step: str, **params: object) -> list[dict[str, object]]:
        result = run_public_query(
            self.trace,
            sql_file=generated_sql(skill, f"{step}.sql"),
            params={**self.params, **params},
        )
        self.assertEqual(result["status"], "ok", result)
        return result["rows"]

    def assert_null_field(self, row: dict[str, object], field: str) -> None:
        # A missing column is a broken contract, not an observed NULL.
        self.assertIn(field, row)
        self.assertIsNone(row[field], field)

    def test_received_updates_do_not_become_frame_count_fps_or_jank(self) -> None:
        rows = self.query("scrolling_analysis", "buffer_tx_performance_fallback")
        self.assertEqual(len(rows), 1)
        row = rows[0]
        for field in ("total_frames", "actual_fps", "perceived_jank_frames", "jank_rate", "sf_jank_count"):
            self.assert_null_field(row, field)
        for field in ("received_buffer_updates", "received_update_rate_hz", "received_update_span_ns"):
            self.assertIn(field, row)
            self.assertGreater(row[field], 0, field)
        self.assertAlmostEqual(
            row["received_update_rate_hz"],
            row["received_buffer_updates"] * 1e9 / row["received_update_span_ns"],
        )
        self.assertEqual(row["buffer_tx_frames"], row["received_buffer_updates"])
        self.assertEqual(row["fps_source"], "buffer_tx_rising_edge_fallback")
        self.assertEqual(row["evidence_status"], "received_buffer_updates_only")
        self.assertIn(PACKAGE, row["frame_source_track"])

    def test_source_event_ratio_above_one_does_not_establish_full_coverage(self) -> None:
        rows = self.query("scrolling_analysis", "buffer_tx_coverage_probe")
        self.assertEqual(len(rows), 1)
        row = rows[0]
        # This owned fixture observes more FrameTimeline events than positive
        # BufferTX deltas. The different populations do not verify each other.
        self.assertGreater(row["frame_timeline_to_buffer_tx_ratio"], 1)
        self.assertEqual(row["root_cause_evidence_scope"], "frame_timeline_only_unbenchmarked")
        self.assertEqual(row["source_event_ratio"], row["frame_timeline_to_buffer_tx_ratio"])
        self.assertEqual(row["source_event_ratio_status"], "heuristic_not_coverage_name_match_only")

    def test_missing_transaction_latch_identity_leaves_latency_unknown(self) -> None:
        rows = self.query("buffer_transaction_lifecycle", "apply_transaction_summary")
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertGreater(row["total_queue_buffer"], 0)
        self.assert_null_field(row, "avg_apply_to_latch_ms")
        self.assertEqual(row["pairing_status"], "unsupported_missing_identity")
        self.assertEqual(row["sf_event_scope"], "global_surfaceflinger")
        self.assertEqual(row["app_event_scope"], "package_and_colon_subprocesses")

    def test_queue_to_transaction_does_not_pair_the_next_global_event(self) -> None:
        rows = self.query("buffer_transaction_lifecycle", "queue_to_transaction_delay")
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row["bucket"], "unavailable_missing_identity")
        self.assert_null_field(row, "count")
        self.assertEqual(row["pairing_status"], "unsupported_missing_identity")

    def test_pending_updates_keep_the_pre_window_sample_without_claiming_frames(self) -> None:
        # Pick one real rising edge with a known preceding sample. A one-ns
        # window isolates it and detects filtering before LAG at the boundary.
        witness = run_public_query(
            self.trace,
            sql="""
                WITH samples AS (
                  SELECT c.id, c.track_id, c.ts, c.value,
                    LAG(c.value) OVER (PARTITION BY c.track_id ORDER BY c.ts, c.id) AS previous_value
                  FROM counter c JOIN counter_track ct ON c.track_id = ct.id
                  WHERE ct.name GLOB 'BufferTX - *' AND INSTR(ct.name, '${package}') > 0
                )
                SELECT track_id, ts, value, value - previous_value AS received_updates
                FROM samples s
                WHERE value > previous_value
                  AND (SELECT COUNT(*) FROM counter c WHERE c.track_id = s.track_id AND c.ts = s.ts) = 1
                ORDER BY ts, id LIMIT 1
            """,
            params={"package": PACKAGE},
        )
        self.assertEqual(witness["status"], "ok", witness)
        self.assertEqual(len(witness["rows"]), 1)
        edge = witness["rows"][0]
        self.assertGreater(edge["received_updates"], 0)
        rows = self.query(
            "buffer_transaction_lifecycle", "buffer_tx_pending_observations",
            start_ts=edge["ts"], end_ts=edge["ts"] + 1,
        )
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row["track_id"], edge["track_id"])
        self.assertEqual(row["sample_count"], 1)
        self.assertEqual(row["received_updates"], edge["received_updates"])
        self.assertEqual(row["removed_updates"], 0)
        self.assertEqual(row["last_pending_updates"], edge["value"])
        self.assertEqual(row["coverage_status"], "observed")
        self.assertEqual(row["evidence_scope"], "package_layer_name_match_not_exact_upid")
        self.assertEqual(row["claim_boundary"], "server_pending_not_gpu_ready_or_presented_frames")
        self.assertNotIn("actual_fps", row)
        self.assertNotIn("total_frames", row)


if __name__ == "__main__":
    unittest.main()

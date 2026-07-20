import unittest

from tests.support import (
    fixture_available,
    fixture_path,
    generated_sql,
    load_skill_script,
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

EXPECTED_SPAN_JOIN_OVERLAP_NS = 233_648_518

SPAN_JOIN_INPUTS_SQL = """
INCLUDE PERFETTO MODULE slices.flat_slices;

CREATE OR REPLACE PERFETTO VIEW target_main_thread_slices AS
SELECT
  fs.ts,
  IIF(fs.dur = -1, trace_end() - fs.ts, fs.dur) AS dur,
  fs.utid,
  fs.slice_id,
  fs.name AS slice_name
FROM _slice_flattened fs
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE p.name = 'com.example.androidappdemo'
  AND t.is_main_thread = 1
  AND IIF(fs.dur = -1, trace_end() - fs.ts, fs.dur) > 0;

CREATE OR REPLACE PERFETTO VIEW target_main_thread_running AS
SELECT
  st.ts,
  IIF(st.dur = -1, trace_end() - st.ts, st.dur) AS dur,
  st.utid,
  st.id AS thread_state_id,
  st.cpu
FROM thread_state st
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE p.name = 'com.example.androidappdemo'
  AND t.is_main_thread = 1
  AND st.state = 'Running'
  AND IIF(st.dur = -1, trace_end() - st.ts, st.dur) > 0;
"""

NON_OVERLAP_WITNESS_SQL = f"""
{SPAN_JOIN_INPUTS_SQL}

WITH slice_overlaps AS (
  SELECT
    utid,
    ts,
    dur,
    LAG(ts + dur) OVER (PARTITION BY utid ORDER BY ts) AS previous_end
  FROM target_main_thread_slices
),
running_overlaps AS (
  SELECT
    utid,
    ts,
    dur,
    LAG(ts + dur) OVER (PARTITION BY utid ORDER BY ts) AS previous_end
  FROM target_main_thread_running
)
SELECT
  (SELECT COUNT(*) FROM slice_overlaps WHERE previous_end > ts)
    AS slice_overlap_violations,
  (SELECT COUNT(*) FROM running_overlaps WHERE previous_end > ts)
    AS running_overlap_violations;
"""

GUARDED_SPAN_JOIN_SQL = f"""
{SPAN_JOIN_INPUTS_SQL}

DROP TABLE IF EXISTS target_main_thread_slice_running_overlap;
-- perfetto-span-join-non-overlap-proof: RealTraceTest witness query
CREATE VIRTUAL TABLE target_main_thread_slice_running_overlap
USING SPAN_JOIN(
  target_main_thread_slices PARTITIONED utid,
  target_main_thread_running PARTITIONED utid
);

SELECT
  SUM(dur) AS overlap_ns,
  COUNT(*) AS overlap_rows
FROM target_main_thread_slice_running_overlap;
"""

sql_guardrails = load_skill_script("perfetto_sql_guardrails")


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

    def test_guarded_span_join_executes_with_non_overlap_witnesses(self) -> None:
        trace = fixture_path("startup-light-api36")
        witness = run_public_query(trace, sql=NON_OVERLAP_WITNESS_SQL)
        self.assertEqual(witness["status"], "ok", witness)
        self.assertEqual(witness["rows"][0]["slice_overlap_violations"], 0)
        self.assertEqual(witness["rows"][0]["running_overlap_violations"], 0)

        blocking_issues = [
            issue
            for issue in sql_guardrails.analyze_sql(GUARDED_SPAN_JOIN_SQL)
            if issue.severity == "error"
        ]
        self.assertEqual(blocking_issues, [])

        overlap = run_public_query(trace, sql=GUARDED_SPAN_JOIN_SQL)
        self.assertEqual(overlap["status"], "ok", overlap)
        self.assertEqual(
            overlap["rows"][0]["overlap_ns"], EXPECTED_SPAN_JOIN_OVERLAP_NS
        )
        self.assertGreater(overlap["rows"][0]["overlap_rows"], 0)


if __name__ == "__main__":
    unittest.main()

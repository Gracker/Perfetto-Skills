-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: 4b5eabe1c5639d55456e498bdf6125fda0f49f1b49a216536b0f7ffde8cf04c7
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

WITH
timing_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (PARTITION BY c.track_id ORDER BY c.ts) AS interval_ns
  FROM counter c JOIN counter_track t ON t.id = c.track_id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
cadence_timing AS (
  SELECT (SELECT PERCENTILE(interval_ns, 50) FROM timing_intervals
    WHERE interval_ns BETWEEN 5500000 AND 50000000) AS vsync_period_ns
),
-- PRESENTATION_CADENCE_CTES_BEGIN
expected_frames AS (
  SELECT upid, layer_name, surface_frame_token,
    CASE WHEN COUNT(*) = 1 AND MIN(dur) > 0 THEN MAX(ts + dur) END AS expected_present_ts
  FROM expected_frame_timeline_slice
  GROUP BY upid, layer_name, surface_frame_token
),
cadence_rows AS (
  SELECT a.id, a.upid, a.layer_name, a.ts, a.dur,
    a.jank_type, a.present_type,
    CASE WHEN a.dur > 0 AND a.present_type != 'Dropped Frame' THEN a.ts + a.dur END AS present_ts,
    CASE WHEN a.dur > 0 AND a.present_type != 'Dropped Frame'
      THEN a.ts + a.dur - e.expected_present_ts END AS lateness_ns
  FROM actual_frame_timeline_slice a
  LEFT JOIN expected_frames e ON e.upid = a.upid AND e.layer_name = a.layer_name
    AND e.surface_frame_token = a.surface_frame_token
  WHERE a.layer_name IS NOT NULL AND a.surface_frame_token IS NOT NULL
    AND (a.layer_name LIKE 'TX - ${package}%' OR a.layer_name = '${layer_name}'
      OR ('${package}' = '' AND '${layer_name}' = ''))
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
),
presented_rows AS (
  SELECT *, present_ts - LAG(present_ts) OVER (
    PARTITION BY upid, layer_name ORDER BY present_ts, id) AS interval_ns
  FROM cadence_rows WHERE present_ts IS NOT NULL
),
burst_rows AS (
  SELECT *, SUM(CASE WHEN interval_ns IS NULL OR interval_ns > 500000000 THEN 1 ELSE 0 END)
    OVER (PARTITION BY upid, layer_name ORDER BY present_ts, id) AS burst_id
  FROM presented_rows
),
cadence_neighbors AS (
  SELECT *, LEAD(interval_ns) OVER (
    PARTITION BY upid, layer_name, burst_id ORDER BY present_ts, id) AS next_interval_ns
  FROM burst_rows
),
cadence_stats AS (
  SELECT upid, layer_name, burst_id, MIN(ts) AS start_ts, MAX(ts + dur) AS end_ts,
    COUNT(*) AS presented_frames,
    SUM(CASE WHEN jank_type GLOB '*Buffer Stuffing*' THEN 1 ELSE 0 END) AS raw_buffer_stuffing_frames,
    SUM(CASE WHEN android_is_missed_frame_type(jank_type) THEN 1 ELSE 0 END) AS missed_frame_type_frames,
    SUM(CASE WHEN present_type = 'Late Present' THEN 1 ELSE 0 END) AS late_present_frames,
    SUM(CASE WHEN interval_ns > 500000000 THEN 1 ELSE 0 END) AS preceding_burst_gaps,
    MAX(CASE WHEN interval_ns > 500000000 THEN interval_ns END) / 1e6 AS preceding_burst_gap_ms,
    SUM(CASE WHEN interval_ns BETWEEN 0 AND 500000000 THEN 1 ELSE 0 END) AS cadence_intervals,
    SUM(CASE WHEN interval_ns BETWEEN period.vsync_period_ns * 0.75 AND period.vsync_period_ns * 1.25 THEN 1 ELSE 0 END) AS near_vsync_intervals,
    SUM(CASE WHEN interval_ns > period.vsync_period_ns * 1.5 AND interval_ns <= 500000000 THEN 1 ELSE 0 END) AS cadence_gap_frames,
    SUM(CASE WHEN present_type = 'Late Present' AND lateness_ns >= period.vsync_period_ns * 0.5
      AND interval_ns BETWEEN period.vsync_period_ns * 0.75 AND period.vsync_period_ns * 1.25
      AND next_interval_ns BETWEEN period.vsync_period_ns * 0.75 AND period.vsync_period_ns * 1.25
      THEN 1 ELSE 0 END) AS steady_late_candidates,
    COUNT(lateness_ns) AS matched_expected_frames,
    AVG(CASE WHEN interval_ns BETWEEN 0 AND 500000000 THEN interval_ns END) / 1e6 AS avg_present_interval_ms,
    MIN(CASE WHEN lateness_ns > 0 THEN lateness_ns / period.vsync_period_ns END) AS min_late_vsyncs,
    MAX(CASE WHEN lateness_ns > 0 THEN lateness_ns / period.vsync_period_ns END) AS max_late_vsyncs,
    period.vsync_period_ns
  FROM cadence_neighbors CROSS JOIN cadence_timing period
  GROUP BY upid, layer_name, burst_id
),
layer_exclusions AS (
  SELECT upid, layer_name,
    SUM(CASE WHEN present_type = 'Dropped Frame' THEN 1 ELSE 0 END) AS dropped_frames,
    SUM(CASE WHEN dur <= 0 OR dur IS NULL THEN 1 ELSE 0 END) AS incomplete_frames
  FROM cadence_rows GROUP BY upid, layer_name
)
-- PRESENTATION_CADENCE_CTES_END
SELECT s.*, s.presented_frames AS total_frames,
  x.dropped_frames, x.incomplete_frames,
  CASE WHEN s.cadence_intervals >= 5 THEN s.steady_late_candidates ELSE 0 END AS steady_late_frames,
  ROUND(100.0 * s.raw_buffer_stuffing_frames / s.presented_frames, 2) AS buffer_stuffing_label_pct,
  CASE
    WHEN s.vsync_period_ns IS NULL OR s.cadence_intervals < 5 THEN 'insufficient_cadence_evidence'
    WHEN s.near_vsync_intervals = s.cadence_intervals AND x.dropped_frames = 0 AND x.incomplete_frames = 0
      THEN CASE WHEN s.steady_late_candidates > 0 THEN 'steady_late' ELSE 'steady_cadence' END
    WHEN s.steady_late_candidates > 0 THEN 'steady_late_with_cadence_excursions'
    ELSE 'variable_cadence'
  END AS cadence_status,
  CASE WHEN s.raw_buffer_stuffing_frames * 2 > s.presented_frames THEN 1 ELSE 0 END AS manual_review_required,
  'vsync_period_from_measured_VSYNC_sf_only; steady_late_requires_5_intervals_and_unique_expected_lateness_at_least_0.5_vsync_and_both_adjacent_intervals_0.75_to_1.25_vsync; cadence_is_not_pipeline_health; preserve_deadline_and_drop_evidence; late_vsyncs_require_unique_expected_match; burst_gaps_and_layer_wide_drop_counts_require_separate_review' AS claim_boundary
FROM cadence_stats s JOIN layer_exclusions x USING (upid, layer_name)
ORDER BY s.upid, s.layer_name, s.burst_id

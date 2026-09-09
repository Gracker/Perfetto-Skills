-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 2dcba698d9cc63e045e9346afc44cab60148cf55a58161bf0378383d624af4ff
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH
-- Fragment: vsync_config
-- Estimates VSync period using scoped then trace-wide VSYNC/FrameTimeline evidence.
-- The explicit 16.67ms default is used only when the trace has no usable timing evidence.
-- Snaps to nearest standard refresh rate (30/60/90/120/144/165 Hz) to avoid
-- half-period toggle contamination and jitter-induced miscalculation.
-- Params: ${start_ts}, ${end_ts}
vsync_ticks AS (
  SELECT c.ts, c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts} - 100000000)
    AND (${end_ts} IS NULL OR c.ts < ${end_ts} + 100000000)
),
trace_vsync_ticks AS (
  SELECT c.ts, c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
),
expected_frame_vsync AS (
  SELECT CAST(PERCENTILE(dur, 50) AS INTEGER) as period_ns
  FROM expected_frame_timeline_slice
  WHERE dur > 5000000 AND dur < 50000000
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
trace_expected_frame_vsync AS (
  SELECT CAST(PERCENTILE(dur, 50) AS INTEGER) as period_ns
  FROM expected_frame_timeline_slice
  WHERE dur > 5000000 AND dur < 50000000
),
raw_vsync_config AS (
  SELECT
    CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 50)
       FROM vsync_ticks
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      (SELECT period_ns FROM expected_frame_vsync WHERE period_ns > 0),
      (SELECT PERCENTILE(interval_ns, 50)
       FROM trace_vsync_ticks
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      (SELECT period_ns FROM trace_expected_frame_vsync WHERE period_ns > 0),
      16666667
    ) AS INTEGER) as raw_ns,
    CASE
      WHEN (SELECT COUNT(*) FROM vsync_ticks WHERE interval_ns > 5500000 AND interval_ns < 50000000) > 0
        THEN CASE
          WHEN ${start_ts} IS NULL OR ${end_ts} IS NULL THEN 'trace_wide_vsync_counter'
          ELSE 'scoped_vsync_counter'
        END
      WHEN (SELECT period_ns FROM expected_frame_vsync WHERE period_ns > 0) IS NOT NULL
        THEN CASE
          WHEN ${start_ts} IS NULL OR ${end_ts} IS NULL THEN 'trace_wide_expected_frame'
          ELSE 'scoped_expected_frame'
        END
      WHEN (SELECT COUNT(*) FROM trace_vsync_ticks WHERE interval_ns > 5500000 AND interval_ns < 50000000) > 0
        THEN 'trace_wide_vsync_counter'
      WHEN (SELECT period_ns FROM trace_expected_frame_vsync WHERE period_ns > 0) IS NOT NULL
        THEN 'trace_wide_expected_frame'
      ELSE 'default_60hz_no_trace_timing'
    END as vsync_source
),
vsync_config AS (
  SELECT
    CASE
      WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
      WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
      WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
      WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
      WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
      WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
      ELSE raw_ns
    END AS vsync_period_ns,
    vsync_source
  FROM raw_vsync_config
)
,
-- BufferTX frame production evidence for one package.
-- Counts only positive per-track queue-depth deltas, then selects one primary
-- track deterministically to avoid summing duplicate producer/layer tracks.
-- Requires vsync_config to be injected before this fragment.
-- BUFFER_TX_FALLBACK_CTES_BEGIN
buffer_tx_samples AS (
  SELECT
    c.id as counter_id,
    c.track_id,
    ct.name as track_name,
    c.ts,
    c.value,
    LAG(c.value) OVER (
      PARTITION BY c.track_id
      ORDER BY c.ts, c.id
    ) as prev_value
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE '${package}' != ''
    AND ct.name GLOB 'BufferTX - *'
    AND INSTR(ct.name, '${package}') > 0
    AND (
      INSTR(ct.name, '${package}') = 1
      OR SUBSTR(ct.name, INSTR(ct.name, '${package}') - 1, 1)
        IN (' ', '[', '(', ':', '/', '-')
    )
    AND (
      INSTR(ct.name, '${package}') + LENGTH('${package}') > LENGTH(ct.name)
      OR SUBSTR(
        ct.name,
        INSTR(ct.name, '${package}') + LENGTH('${package}'),
        1
      ) IN ('/', ':', '#', ']', ')', ' ')
    )
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
buffer_tx_deltas AS (
  SELECT
    counter_id,
    track_id,
    track_name,
    ts,
    CASE
      WHEN prev_value IS NOT NULL AND value > prev_value
        THEN CAST(value - prev_value AS INTEGER)
      ELSE 0
    END as produced_frames
  FROM buffer_tx_samples
),
buffer_tx_track_stats AS (
  SELECT
    track_id,
    track_name,
    CAST(SUM(produced_frames) AS INTEGER) as produced_frames,
    MIN(ts) as first_sample_ts,
    MAX(ts) as last_sample_ts,
    MAX(ts) - MIN(ts) as effective_span_ns
  FROM buffer_tx_deltas
  GROUP BY track_id, track_name
  HAVING SUM(produced_frames) >= 5
    AND MAX(ts) > MIN(ts)
    AND MAX(ts) - MIN(ts) >= 5 * (SELECT vsync_period_ns FROM vsync_config)
),
selected_buffer_tx_track AS (
  SELECT *
  FROM buffer_tx_track_stats
  ORDER BY produced_frames DESC, effective_span_ns DESC, track_id ASC
  LIMIT 1
)
-- BUFFER_TX_FALLBACK_CTES_END
,
frame_timeline_coverage AS (
  SELECT COUNT(DISTINCT CASE
    WHEN a.display_frame_token IS NOT NULL
      THEN 'display:' || CAST(a.display_frame_token AS TEXT)
    WHEN a.surface_frame_token IS NOT NULL
      THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
    ELSE NULL
  END) as frame_timeline_frames
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (
    '${package}' = ''
    OR p.name = '${package}'
    OR p.name GLOB '${package}:*'
  )
    AND p.name NOT LIKE '/system/%'
    -- With no target package the clause above accepts any process, and
    -- the system UI is the one most likely to be drawing while the target
    -- app draws nothing. Its frames are punctual, so they read back as
    -- flawless scrolling for an app that produced no frames at all: one
    -- device reported 31fps SystemUI frames as "优秀", another rated a
    -- 5-frame notification-shade window. Anyone analysing the system UI
    -- deliberately names it and keeps these rows.
    AND ('${package}' != '' OR p.name NOT LIKE 'com.android.systemui%')
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
),
fallback_summary AS (
  SELECT
    bt.produced_frames as total_frames,
    ROUND(bt.effective_span_ns / 1e9, 3) as duration_sec,
    MIN(
      ROUND(bt.produced_frames * 1e9 / NULLIF(bt.effective_span_ns, 0), 1),
      CAST(ROUND(1e9 / (SELECT vsync_period_ns FROM vsync_config)) AS INTEGER)
    ) as actual_fps,
    bt.track_name as frame_source_track,
    ft.frame_timeline_frames,
    ROUND(ft.frame_timeline_frames * 1.0 / bt.produced_frames, 4) as frame_timeline_to_buffer_tx_ratio,
    CASE
      WHEN ft.frame_timeline_frames = 0 THEN 'no_frame_timeline_coverage'
      ELSE 'partial_frame_timeline_coverage'
    END as coverage_status
  FROM selected_buffer_tx_track bt
  CROSS JOIN frame_timeline_coverage ft
)
SELECT
  total_frames,
  NULL as perceived_jank_frames,
  NULL as jank_rate,
  NULL as buffer_stuffing_frames,
  NULL as janky_frames,
  NULL as app_janky_frames,
  NULL as sf_jank_count,
  NULL as app_jank_rate,
  NULL as buffer_stuffing_rate,
  NULL as avg_frame_dur,
  NULL as max_frame_dur,
  NULL as median_frame_dur,
  NULL as p95_frame_dur,
  NULL as p99_frame_dur,
  duration_sec,
  actual_fps,
  CAST(ROUND(1e9 / (SELECT vsync_period_ns FROM vsync_config)) AS INTEGER) as refresh_rate,
  '仅帧率（FrameTimeline 根因证据不足）' as rating,
  'buffer_tx_rising_edge_fallback' as fps_source,
  NULL as max_vsync_missed,
  NULL as total_vsync_missed,
  ROUND((SELECT vsync_period_ns FROM vsync_config) / 1e6, 2) as vsync_period_ms,
  (SELECT vsync_source FROM vsync_config) as vsync_source,
  frame_source_track,
  frame_timeline_frames,
  total_frames as buffer_tx_frames,
  frame_timeline_to_buffer_tx_ratio,
  coverage_status,
  'frame_rate_only' as evidence_status
FROM fallback_summary

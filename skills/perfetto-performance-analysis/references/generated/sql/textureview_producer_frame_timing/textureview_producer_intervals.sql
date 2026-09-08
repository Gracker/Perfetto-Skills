-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/textureview_producer_frame_timing.skill.yaml
-- Source SHA-256: a2c34451c741e02fc6d13ed92dc82fdb910606ab79c16c5996ce90becc55c588
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
display_config AS (
  SELECT
    CAST(COALESCE(${target_frame_ms} * 1000000.0, vsync_period_ns) AS INTEGER) AS display_vsync_ns,
    CASE
      WHEN ${target_frame_ms} IS NOT NULL THEN 'explicit_target_frame_ms'
      ELSE vsync_source
    END AS vsync_source
  FROM vsync_config
),
textureview_processes AS (
  SELECT DISTINCT p.upid
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name = i.target_process OR p.name GLOB i.target_process || ':*')
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND COALESCE(t.name, '') NOT GLOB '1.ui*'
    AND COALESCE(t.name, '') NOT GLOB '1.raster*'
    AND (
      s.name GLOB '*SurfaceTexture*' OR
      s.name GLOB '*updateTexImage*' OR
      s.name GLOB '*onFrameAvailable*' OR
      s.name GLOB '*DeferredLayerUpdater*'
    )
),
cadence_events AS (
  SELECT
    s.ts,
    s.name AS event_name,
    CASE
      WHEN (s.name GLOB '*queueBuffer*' AND s.name NOT GLOB '*dequeueBuffer*')
        OR s.name GLOB '*eglSwapBuffers*'
        OR s.name GLOB '*vkQueuePresent*' THEN 'producer_submit'
      WHEN s.name GLOB '*onFrameAvailable*' THEN 'consumer_notification'
    END AS event_role,
    CASE
      WHEN s.name GLOB '*queueBuffer*' AND s.name NOT GLOB '*dequeueBuffer*' THEN 'queue_buffer'
      WHEN s.name GLOB '*eglSwapBuffers*' THEN 'egl_swap_buffers'
      WHEN s.name GLOB '*vkQueuePresent*' THEN 'vk_queue_present'
      WHEN s.name GLOB '*onFrameAvailable*' THEN 'frame_available'
    END AS event_stream,
    t.utid,
    COALESCE(t.name, '<unnamed>') AS thread_name,
    p.name AS process_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name = i.target_process OR p.name GLOB i.target_process || ':*')
    AND p.upid IN (SELECT upid FROM textureview_processes)
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND COALESCE(t.name, '') NOT GLOB '1.ui*'
    AND COALESCE(t.name, '') NOT GLOB '1.raster*'
    AND (
      s.name GLOB '*onFrameAvailable*' OR
      (s.name GLOB '*queueBuffer*' AND s.name NOT GLOB '*dequeueBuffer*') OR
      s.name GLOB '*eglSwapBuffers*' OR
      s.name GLOB '*vkQueuePresent*'
    )
),
raw_intervals AS (
  SELECT
    ts,
    event_name,
    event_role,
    event_stream,
    utid,
    LAG(event_name) OVER (PARTITION BY utid, event_stream ORDER BY ts) AS previous_event_name,
    ts - LAG(ts) OVER (PARTITION BY utid, event_stream ORDER BY ts) AS interval_ns,
    thread_name,
    process_name
  FROM cadence_events
),
stream_periods AS (
  SELECT
    r.utid,
    r.event_role,
    r.event_stream,
    CAST(PERCENTILE(r.interval_ns, 50) AS INTEGER) AS stream_period_ns
  FROM raw_intervals r
  CROSS JOIN display_config d
  WHERE r.interval_ns > 0
    AND r.interval_ns <= d.display_vsync_ns * 6
  GROUP BY r.utid, r.event_role, r.event_stream
),
qualified_streams AS (
  SELECT p.*
  FROM stream_periods p
  CROSS JOIN display_config d
  WHERE p.stream_period_ns >= d.display_vsync_ns * 0.5
),
evaluated_intervals AS (
  SELECT
    r.*,
    d.display_vsync_ns,
    d.vsync_source,
    p.stream_period_ns,
    MAX(d.display_vsync_ns, COALESCE(p.stream_period_ns, d.display_vsync_ns)) AS cadence_baseline_ns
  FROM raw_intervals r
  CROSS JOIN display_config d
  JOIN qualified_streams p
    ON p.utid = r.utid
   AND p.event_stream = r.event_stream
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', interval_ns) AS interval_ns,
  ROUND(interval_ns / 1e6, 2) AS interval_ms,
  CAST(MAX(0, ROUND(interval_ns * 1.0 / cadence_baseline_ns) - 1) AS INTEGER) AS vsync_missed,
  event_role,
  event_stream,
  event_name,
  previous_event_name,
  thread_name,
  process_name,
  ROUND(display_vsync_ns / 1e6, 2) AS display_vsync_ms,
  ROUND(stream_period_ns / 1e6, 2) AS stream_period_ms,
  ROUND(cadence_baseline_ns / 1e6, 2) AS cadence_baseline_ms,
  vsync_source,
  'per_thread_event_stream_cadence_gap_candidate' AS evidence_scope,
  'timing_gap_candidate_not_jank_without_frame_correlation' AS claim_boundary,
  CASE
    WHEN interval_ns > cadence_baseline_ns * 4 THEN 'critical'
    WHEN interval_ns > cadence_baseline_ns * 2 THEN 'warning'
    WHEN interval_ns > cadence_baseline_ns * 1.5 THEN 'notice'
    ELSE 'normal'
  END AS rating
FROM evaluated_intervals
WHERE interval_ns IS NOT NULL
  AND interval_ns > cadence_baseline_ns * 1.5
  AND interval_ns <= cadence_baseline_ns * 6
ORDER BY interval_ns DESC
LIMIT 100

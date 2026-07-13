-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/sf_frame_consumption.skill.yaml
-- Source SHA-256: 45c4f9d714bd602d37b6011a5c75d3aa1293dc5e685525319a2af173b801d580
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts + dur)) as end_ts
  FROM actual_frame_timeline_slice
),
sf_frames AS (
  SELECT
    a.ts as present_ts,
    a.dur,
    a.layer_name,
    a.surface_frame_token,
    a.display_frame_token,
    a.jank_type,
    a.on_time_finish,
    a.present_type,
    ROW_NUMBER() OVER (ORDER BY a.ts) as frame_num,
    LAG(a.ts) OVER (ORDER BY a.ts) as prev_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE a.surface_frame_token IS NOT NULL
    AND (p.name GLOB '${package}*' OR '${package}' = '' OR a.layer_name GLOB '*${package}*')
    AND a.ts >= (SELECT start_ts FROM time_bounds)
    AND a.ts <= (SELECT end_ts FROM time_bounds)
),
frame_intervals AS (
  SELECT
    present_ts - prev_ts as interval_ns,
    jank_type,
    on_time_finish,
    present_type
  FROM sf_frames
  WHERE prev_ts IS NOT NULL
),
consumption_stats AS (
  SELECT
    COUNT(*) as total_consumed_frames,
    (SELECT end_ts - start_ts FROM time_bounds) as total_duration_ns,
    COUNT(CASE WHEN jank_type = 'None' THEN 1 END) as on_time_frames,
    COUNT(CASE WHEN jank_type != 'None' THEN 1 END) as janky_frames,
    AVG(interval_ns) as avg_interval_ns,
    PERCENTILE(interval_ns, 0.5) as median_interval_ns,
    MIN(interval_ns) as min_interval_ns,
    MAX(interval_ns) as max_interval_ns
  FROM frame_intervals
)
SELECT
  total_consumed_frames,
  ROUND(total_duration_ns / 1e6, 1) as duration_ms,
  ROUND(total_duration_ns / 1e9, 2) as duration_sec,
  on_time_frames,
  janky_frames,
  ROUND(100.0 * janky_frames / NULLIF(total_consumed_frames, 0), 2) as jank_rate,
  ROUND(1e9 / NULLIF(avg_interval_ns, 0), 1) as avg_fps,
  ROUND(1e9 / NULLIF(median_interval_ns, 0), 1) as median_fps,
  ROUND(1e9 * total_consumed_frames / NULLIF(total_duration_ns, 0), 1) as actual_fps,
  ROUND(avg_interval_ns / 1e6, 2) as avg_interval_ms,
  ROUND(median_interval_ns / 1e6, 2) as median_interval_ms,
  ROUND(min_interval_ns / 1e6, 2) as min_interval_ms,
  ROUND(max_interval_ns / 1e6, 2) as max_interval_ms
FROM consumption_stats

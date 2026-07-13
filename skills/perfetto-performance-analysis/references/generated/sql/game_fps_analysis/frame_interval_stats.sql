-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/game_fps_analysis.skill.yaml
-- Source SHA-256: 149fad0ed589259b19b7d70e8969cf12c77fc86255551b55aeea19b9705ed7fe
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts + dur)) as end_ts
  FROM actual_frame_timeline_slice
),
frame_intervals AS (
  SELECT
    a.ts,
    a.ts - LAG(a.ts) OVER (ORDER BY a.ts) as interval_ns,
    a.dur
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND a.surface_frame_token IS NOT NULL
    AND a.ts >= (SELECT start_ts FROM time_bounds)
    AND a.ts <= (SELECT end_ts FROM time_bounds)
)
SELECT
  COUNT(*) as total_frames,
  ROUND((SELECT end_ts - start_ts FROM time_bounds) / 1e9, 2) as duration_sec,
  ROUND(1e9 * COUNT(*) / NULLIF((SELECT end_ts - start_ts FROM time_bounds), 0), 1) as actual_fps,
  ROUND(AVG(interval_ns) / 1e6, 2) as avg_interval_ms,
  ROUND(MIN(interval_ns) / 1e6, 2) as min_interval_ms,
  ROUND(MAX(interval_ns) / 1e6, 2) as max_interval_ms,
  ROUND(PERCENTILE(interval_ns, 0.5) / 1e6, 2) as p50_interval_ms,
  ROUND(PERCENTILE(interval_ns, 0.95) / 1e6, 2) as p95_interval_ms,
  ROUND(PERCENTILE(interval_ns, 0.99) / 1e6, 2) as p99_interval_ms,
  -- 帧间隔标准差 (稳定性指标)
  ROUND(SQRT(AVG(interval_ns * interval_ns) - AVG(interval_ns) * AVG(interval_ns)) / 1e6, 2) as interval_stddev_ms
FROM frame_intervals
WHERE interval_ns IS NOT NULL
  AND interval_ns > 5000000
  AND interval_ns < 100000000

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/game_fps_analysis.skill.yaml
-- Source SHA-256: b1c2c2f4499e3075a69a03b7dbde88b4145a3b8dea465d645cd175f697d90442
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
  WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
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
  ROUND(PERCENTILE(interval_ns, 50) / 1e6, 2) as p50_interval_ms,
  ROUND(PERCENTILE(interval_ns, 95) / 1e6, 2) as p95_interval_ms,
  ROUND(PERCENTILE(interval_ns, 99) / 1e6, 2) as p99_interval_ms,
  -- 帧间隔标准差 (稳定性指标)
  ROUND(SQRT(AVG(interval_ns * interval_ns) - AVG(interval_ns) * AVG(interval_ns)) / 1e6, 2) as interval_stddev_ms
FROM frame_intervals
WHERE interval_ns IS NOT NULL
  AND interval_ns > 5000000
  AND interval_ns < 100000000

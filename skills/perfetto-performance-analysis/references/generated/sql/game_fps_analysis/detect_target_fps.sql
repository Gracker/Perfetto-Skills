-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/game_fps_analysis.skill.yaml
-- Source SHA-256: f104c2ead1d211e29902fa0d4c1b768f407c2f8d942c1076311f373222ff92ab

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts + dur)) as end_ts
  FROM actual_frame_timeline_slice
),
frame_intervals AS (
  SELECT
    a.ts - LAG(a.ts) OVER (ORDER BY a.ts) as interval_ns
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
    AND a.surface_frame_token IS NOT NULL
    AND a.ts >= (SELECT start_ts FROM time_bounds)
    AND a.ts <= (SELECT end_ts FROM time_bounds)
),
interval_buckets AS (
  SELECT
    interval_ns,
    CASE
      WHEN interval_ns >= 30000000 AND interval_ns < 36000000 THEN '30fps'
      WHEN interval_ns >= 20000000 AND interval_ns < 24000000 THEN '45fps'
      WHEN interval_ns >= 14500000 AND interval_ns < 18500000 THEN '60fps'
      WHEN interval_ns >= 10500000 AND interval_ns < 13500000 THEN '90fps'
      WHEN interval_ns >= 7000000 AND interval_ns < 10000000 THEN '120fps'
      WHEN interval_ns >= 6600000 AND interval_ns < 7400000 THEN '144fps'
      WHEN interval_ns >= 5800000 AND interval_ns < 6400000 THEN '165fps'
      ELSE 'variable'
    END as fps_bucket
  FROM frame_intervals
  WHERE interval_ns IS NOT NULL
    AND interval_ns > 5000000
    AND interval_ns < 100000000
),
bucket_counts AS (
  SELECT fps_bucket, COUNT(*) as cnt
  FROM interval_buckets
  GROUP BY fps_bucket
  ORDER BY cnt DESC
), selected_target AS (
  SELECT CASE WHEN ${target_fps} > 0 THEN ${target_fps}
    ELSE CASE (SELECT fps_bucket FROM bucket_counts LIMIT 1)
      WHEN '30fps' THEN 30 WHEN '45fps' THEN 45
      WHEN '60fps' THEN 60 WHEN '90fps' THEN 90
      WHEN '120fps' THEN 120 WHEN '144fps' THEN 144
      WHEN '165fps' THEN 165 END END AS target_fps
), target_config AS (
  SELECT target_fps,
    -- Retain the existing preset buckets; other explicit targets have
    -- no bucket-based hit count, but still define the jank threshold.
    CASE WHEN target_fps IN (30, 45, 60, 90, 120, 144, 165)
      THEN CAST(target_fps AS TEXT) || 'fps' END AS target_bucket
  FROM selected_target
)
SELECT
  COALESCE((SELECT fps_bucket FROM bucket_counts LIMIT 1), 'variable') AS detected_fps_mode,
  1e9 / target_fps AS target_interval_ns,
  target_fps,
  CASE WHEN target_bucket IS NOT NULL THEN
    COALESCE((SELECT cnt FROM bucket_counts WHERE fps_bucket = target_bucket), 0)
  END AS frames_at_target,
  (SELECT COUNT(*) FROM interval_buckets) AS total_frames,
  CASE WHEN target_bucket IS NOT NULL THEN
    ROUND(100.0 * COALESCE((SELECT cnt FROM bucket_counts WHERE fps_bucket = target_bucket), 0)
      / NULLIF((SELECT COUNT(*) FROM interval_buckets), 0), 1)
  END AS target_hit_rate
FROM target_config

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/game_fps_analysis.skill.yaml
-- Source SHA-256: 149fad0ed589259b19b7d70e8969cf12c77fc86255551b55aeea19b9705ed7fe
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
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
)
SELECT
  COALESCE(
    (SELECT fps_bucket FROM bucket_counts LIMIT 1),
    'variable'
  ) as detected_fps_mode,
  CASE (SELECT fps_bucket FROM bucket_counts LIMIT 1)
    WHEN '30fps' THEN 33333333
    WHEN '45fps' THEN 22222222
    WHEN '60fps' THEN 16666666
    WHEN '90fps' THEN 11111111
    WHEN '120fps' THEN 8333333
    WHEN '144fps' THEN 6944444
    WHEN '165fps' THEN 6060606
    ELSE 8333333
  END as target_interval_ns,
  CASE (SELECT fps_bucket FROM bucket_counts LIMIT 1)
    WHEN '30fps' THEN 30
    WHEN '45fps' THEN 45
    WHEN '60fps' THEN 60
    WHEN '90fps' THEN 90
    WHEN '120fps' THEN 120
    WHEN '144fps' THEN 144
    WHEN '165fps' THEN 165
    ELSE 120
  END as target_fps,
  (SELECT cnt FROM bucket_counts LIMIT 1) as frames_at_target,
  (SELECT SUM(cnt) FROM bucket_counts) as total_frames,
  ROUND(100.0 * (SELECT cnt FROM bucket_counts LIMIT 1) / NULLIF((SELECT SUM(cnt) FROM bucket_counts), 0), 1) as target_hit_rate

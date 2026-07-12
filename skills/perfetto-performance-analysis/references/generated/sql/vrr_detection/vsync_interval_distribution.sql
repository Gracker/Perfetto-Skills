-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vrr_detection.skill.yaml
-- Source SHA-256: dbd96fdb066f3be0defa9135a69e115de91d28e52f9f9585a9fad0f12fd2cd06
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts)) as end_ts
  FROM counter
),
-- 从 VSYNC-sf 信号获取 VSync 间隔
vsync_intervals AS (
  SELECT
    interval.ts,
    interval.dur as interval_ns
  FROM counter_leading_intervals!((
    SELECT c.*
    FROM counter c
    JOIN counter_track t ON c.track_id = t.id
    WHERE (t.name GLOB '*VSYNC-sf*' OR t.name = 'VSYNC')
  )) AS interval
  WHERE interval.ts >= (SELECT start_ts FROM time_bounds)
    AND interval.ts <= (SELECT end_ts FROM time_bounds)
),
-- 将间隔归类到刷新率档位
interval_buckets AS (
  SELECT
    interval_ns,
    CASE
      WHEN interval_ns < 6500000 THEN '165Hz'
      WHEN interval_ns < 7500000 THEN '144Hz'
      WHEN interval_ns < 9000000 THEN '120Hz'
      WHEN interval_ns < 12000000 THEN '90Hz'
      WHEN interval_ns < 20000000 THEN '60Hz'
      WHEN interval_ns < 35000000 THEN '30Hz'
      ELSE 'Other'
    END as refresh_rate_bucket,
    CASE
      WHEN interval_ns < 6500000 THEN 1
      WHEN interval_ns < 7500000 THEN 2
      WHEN interval_ns < 9000000 THEN 3
      WHEN interval_ns < 12000000 THEN 4
      WHEN interval_ns < 20000000 THEN 5
      WHEN interval_ns < 35000000 THEN 6
      ELSE 7
    END as bucket_order
  FROM vsync_intervals
  WHERE interval_ns IS NOT NULL
    AND interval_ns > 5500000   -- 排除半周期 toggle 污染
    AND interval_ns < 100000000  -- 过滤异常值
)
SELECT
  refresh_rate_bucket,
  COUNT(*) as frame_count,
  ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) as percentage,
  ROUND(SUM(interval_ns) / 1e9, 2) as total_duration_sec,
  ROUND(AVG(interval_ns) / 1e6, 2) as avg_interval_ms,
  bucket_order
FROM interval_buckets
GROUP BY refresh_rate_bucket, bucket_order
HAVING COUNT(*) >= 5  -- 至少 5 帧才统计
ORDER BY bucket_order

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vrr_detection.skill.yaml
-- Source SHA-256: dbd96fdb066f3be0defa9135a69e115de91d28e52f9f9585a9fad0f12fd2cd06
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH
vsync_intervals AS (
  SELECT
    interval.dur as interval_ns
  FROM counter_leading_intervals!((
    SELECT c.*
    FROM counter c
    JOIN counter_track t ON c.track_id = t.id
    WHERE t.name = 'VSYNC-sf'
  )) AS interval
),
interval_buckets AS (
  SELECT
    CASE
      WHEN interval_ns < 6500000 THEN '165Hz'
      WHEN interval_ns < 7500000 THEN '144Hz'
      WHEN interval_ns < 9000000 THEN '120Hz'
      WHEN interval_ns < 12000000 THEN '90Hz'
      WHEN interval_ns < 20000000 THEN '60Hz'
      WHEN interval_ns < 35000000 THEN '30Hz'
      ELSE 'Other'
    END as bucket
  FROM vsync_intervals
  WHERE interval_ns IS NOT NULL
    AND interval_ns > 5500000
    AND interval_ns < 100000000
),
bucket_counts AS (
  SELECT bucket, COUNT(*) as cnt
  FROM interval_buckets
  GROUP BY bucket
  HAVING COUNT(*) >= 10
),
stats AS (
  SELECT
    COUNT(DISTINCT bucket) as distinct_buckets,
    (SELECT COUNT(*) FROM vsync_intervals WHERE interval_ns IS NOT NULL) as total_intervals,
    (SELECT ROUND(100.0 * MAX(cnt) / NULLIF(SUM(cnt), 0), 1) FROM bucket_counts) as dominant_pct
  FROM bucket_counts
)
SELECT
  CASE
    WHEN distinct_buckets >= 3 THEN 'VRR_ACTIVE'
    WHEN distinct_buckets = 2 THEN 'VRR_LIMITED'
    ELSE 'FIXED_RATE'
  END as vrr_mode,
  distinct_buckets as active_refresh_rates,
  dominant_pct as dominant_rate_pct,
  CASE
    WHEN distinct_buckets >= 3 THEN '检测到 VRR/LTPO 模式，刷新率动态变化'
    WHEN distinct_buckets = 2 THEN '检测到双档刷新率切换'
    ELSE '固定刷新率模式'
  END as mode_description,
  total_intervals as sample_count
FROM stats

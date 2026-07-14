-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vrr_detection.skill.yaml
-- Source SHA-256: dbd96fdb066f3be0defa9135a69e115de91d28e52f9f9585a9fad0f12fd2cd06
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH
vsync_intervals AS (
  SELECT
    interval.ts,
    interval.dur as interval_ns
  FROM counter_leading_intervals!((
    SELECT c.*
    FROM counter c
    JOIN counter_track t ON c.track_id = t.id
    WHERE t.name = 'VSYNC-sf'
  )) AS interval
),
with_buckets AS (
  SELECT
    ts,
    interval_ns,
    CASE
      WHEN interval_ns < 9000000 THEN '120Hz'
      WHEN interval_ns < 12000000 THEN '90Hz'
      WHEN interval_ns < 20000000 THEN '60Hz'
      ELSE '30Hz'
    END as bucket,
    LAG(CASE
      WHEN interval_ns < 9000000 THEN '120Hz'
      WHEN interval_ns < 12000000 THEN '90Hz'
      WHEN interval_ns < 20000000 THEN '60Hz'
      ELSE '30Hz'
    END) OVER (ORDER BY ts) as prev_bucket
  FROM vsync_intervals
  WHERE interval_ns IS NOT NULL
    AND interval_ns > 5500000
    AND interval_ns < 100000000
)
SELECT
  prev_bucket || ' → ' || bucket as transition,
  COUNT(*) as switch_count
FROM with_buckets
WHERE bucket != prev_bucket
  AND prev_bucket IS NOT NULL
GROUP BY prev_bucket, bucket
ORDER BY switch_count DESC

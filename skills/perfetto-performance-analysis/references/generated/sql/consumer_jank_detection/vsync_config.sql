-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: 4b5eabe1c5639d55456e498bdf6125fda0f49f1b49a216536b0f7ffde8cf04c7
-- Source commit: bc007586871a720aed82537913617c64fb95a459

WITH
sf_vsync_intervals AS (
  SELECT
    c.ts - LAG(c.ts) OVER (PARTITION BY c.track_id ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_median AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST((SELECT PERCENTILE(interval_ns, 50)
      FROM sf_vsync_intervals
      WHERE interval_ns > 5500000 AND interval_ns < 50000000
    ) AS INTEGER) AS raw_ns
  )
)
SELECT
  vsync_period_ns,
  CAST(ROUND(1e9 / vsync_period_ns) AS INTEGER) as refresh_rate_hz
FROM vsync_median

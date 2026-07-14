-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
sf_vsync_intervals AS (
  SELECT
    c.ts,
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_median AS (
  SELECT
    CASE
      WHEN raw_period BETWEEN 5500000 AND 6500000 THEN 6060606
      WHEN raw_period BETWEEN 6500001 AND 7500000 THEN 6944444
      WHEN raw_period BETWEEN 7500001 AND 9500000 THEN 8333333
      WHEN raw_period BETWEEN 9500001 AND 12500000 THEN 11111111
      WHEN raw_period BETWEEN 12500001 AND 20000000 THEN 16666667
      WHEN raw_period BETWEEN 20000001 AND 35000000 THEN 33333333
      ELSE raw_period
    END AS vsync_period_ns,
    source
  FROM (
    SELECT
      CAST(COALESCE(
        (SELECT PERCENTILE(interval_ns, 0.5)
         FROM sf_vsync_intervals
         WHERE interval_ns > 5500000 AND interval_ns < 50000000),
        16666667
      ) AS INTEGER) as raw_period,
      CASE
        WHEN (SELECT COUNT(*) FROM sf_vsync_intervals WHERE interval_ns > 5500000 AND interval_ns < 50000000) > 0 THEN 'sf_vsync_counter'
        ELSE 'default'
      END as source
  )
)
SELECT
  CAST(ROUND(1e9 / vsync_period_ns) AS INTEGER) as refresh_rate_hz,
  ROUND(vsync_period_ns / 1e6, 2) as vsync_period_ms,
  vsync_period_ns,
  source as vsync_source
FROM vsync_median

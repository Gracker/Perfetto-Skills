-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 3f8a18a4750d12e34a5556236cf069b5e09eaf1c3c3cf2cc5af513f635809c46
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
),
filtered AS (
  SELECT interval_ns FROM vsync_intervals
  WHERE interval_ns BETWEEN 5500000 AND 50000000
),
snapped AS (
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
    SELECT CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER) AS raw_ns
    FROM filtered
  )
)
SELECT
  vsync_period_ns,
  CAST(ROUND(1e9 / vsync_period_ns) AS INTEGER) as refresh_rate_hz
FROM snapped

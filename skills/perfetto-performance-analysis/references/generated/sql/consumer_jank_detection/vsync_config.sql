-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: bd6cecfa7dc06e2b74d023498fb38d336bec28f1214c4364880f4091e2ffb7fa
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH
sf_vsync_intervals AS (
  SELECT
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
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
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 50)
       FROM sf_vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      (SELECT CAST(PERCENTILE(dur, 50) AS INTEGER)
       FROM expected_frame_timeline_slice
       WHERE dur > 5000000 AND dur < 50000000
         AND (${start_ts} IS NULL OR ts >= ${start_ts})
         AND (${end_ts} IS NULL OR ts < ${end_ts})),
      16666667
    ) AS INTEGER) AS raw_ns
  )
)
SELECT
  vsync_period_ns,
  CAST(ROUND(1e9 / vsync_period_ns) AS INTEGER) as refresh_rate_hz
FROM vsync_median

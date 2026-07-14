-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH
-- VSync 周期：VSYNC-sf 中位数 + 标准刷新率吸附（30/60/90/120/144/165Hz）
sf_vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
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
      COALESCE(
        (SELECT CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER)
         FROM sf_vsync_intervals
         WHERE interval_ns > 5500000 AND interval_ns < 50000000),
        (SELECT CAST(PERCENTILE(dur, 0.5) AS INTEGER)
         FROM expected_frame_timeline_slice
         WHERE dur > 5000000 AND dur < 50000000
           AND (${start_ts} IS NULL OR ts >= ${start_ts})
           AND (${end_ts} IS NULL OR ts < ${end_ts})),
        16666667
      ) AS raw_period,
      CASE
        WHEN (SELECT COUNT(*) FROM sf_vsync_intervals WHERE interval_ns > 5500000 AND interval_ns < 50000000) > 0 THEN 'sf_vsync_counter'
        WHEN (SELECT COUNT(*) FROM expected_frame_timeline_slice WHERE dur > 5000000 AND dur < 50000000) > 0 THEN 'expected_frame'
        ELSE 'default'
      END AS source
  )
),
frame_count AS (
  SELECT COUNT(*) as total_frames
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
)
SELECT
  vsync_period_ns,
  CAST(ROUND(1e9 / vsync_period_ns) AS INTEGER) as refresh_rate_hz,
  ROUND(vsync_period_ns / 1e6, 2) as vsync_period_ms,
  source as vsync_source,
  (SELECT total_frames FROM frame_count) as total_frames,
  CASE WHEN (SELECT total_frames FROM frame_count) > 0 THEN 1 ELSE 0 END as has_data
FROM vsync_median

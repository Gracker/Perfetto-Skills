-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_period_detection.skill.yaml
-- Source SHA-256: b6139b2a252fbc4644978e6801b666ac16d081516ec77a75c8cb3d86da538043
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

-- VSync Period Detection with Multiple Sources
--
-- Strategy:
-- 1. Try VSYNC-sf counter median (most reliable)
-- 2. Fall back to expected_frame_timeline_slice median
-- 3. Default 60Hz fallback

WITH params AS (
  SELECT
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT MAX(ts) FROM counter)) AS end_ts
),

-- Source 1: VSYNC-sf counter intervals
vsync_sf_raw AS (
  SELECT
    c.ts,
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  CROSS JOIN params p
  WHERE t.name = 'VSYNC-sf'
    AND c.ts >= p.start_ts
    AND c.ts <= p.end_ts
),

vsync_sf_stats AS (
  SELECT
    CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER) AS median_period_ns,
    COUNT(*) AS sample_count
  FROM vsync_sf_raw
  WHERE interval_ns IS NOT NULL
    AND interval_ns > 5500000
    AND interval_ns < 50000000
),

-- Source 2: expected_frame_timeline_slice durations (fallback)
frame_timeline_stats AS (
  SELECT
    CAST(PERCENTILE(dur, 0.5) AS INTEGER) AS median_period_ns,
    COUNT(*) AS sample_count
  FROM expected_frame_timeline_slice e
  CROSS JOIN params p
  WHERE e.ts >= p.start_ts
    AND e.ts <= p.end_ts
    AND e.dur > 5000000
    AND e.dur < 50000000
),

-- Choose best source, then snap to standard Hz
detected_period AS (
  SELECT
    CASE
      WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
      WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
      WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
      WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
      WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
      WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
      ELSE raw_ns
    END AS vsync_period_ns,
    detection_method,
    confidence,
    sample_count
  FROM (
    SELECT
      CASE
        WHEN (SELECT sample_count FROM vsync_sf_stats) >= 10
          THEN (SELECT median_period_ns FROM vsync_sf_stats)
        WHEN (SELECT sample_count FROM frame_timeline_stats) >= 10
          THEN (SELECT median_period_ns FROM frame_timeline_stats)
        ELSE 16666667
      END AS raw_ns,
      CASE
        WHEN (SELECT sample_count FROM vsync_sf_stats) >= 10 THEN 'vsync_sf'
        WHEN (SELECT sample_count FROM frame_timeline_stats) >= 10 THEN 'frame_timeline'
        ELSE 'default'
      END AS detection_method,
      CASE
        WHEN (SELECT sample_count FROM vsync_sf_stats) >= 100 THEN 0.95
        WHEN (SELECT sample_count FROM vsync_sf_stats) >= 10 THEN 0.85
        WHEN (SELECT sample_count FROM frame_timeline_stats) >= 100 THEN 0.80
        WHEN (SELECT sample_count FROM frame_timeline_stats) >= 10 THEN 0.70
        ELSE 0.50
      END AS confidence,
      COALESCE(
        (SELECT sample_count FROM vsync_sf_stats),
        (SELECT sample_count FROM frame_timeline_stats),
        0
      ) AS sample_count
  )
)

SELECT
  vsync_period_ns,
  CAST(ROUND(1e9 / vsync_period_ns) AS INTEGER) AS detected_refresh_rate_hz,
  vsync_period_ns AS measured_period_ns,
  detection_method,
  confidence,
  sample_count,
  ROUND(1000000000.0 / vsync_period_ns, 1) AS theoretical_fps
FROM detected_period

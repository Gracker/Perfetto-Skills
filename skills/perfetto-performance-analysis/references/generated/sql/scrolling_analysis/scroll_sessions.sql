-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH
-- 动态 VSync 周期检测用于 session 切分（限定在分析区间内）
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config AS (
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
      (SELECT PERCENTILE(interval_ns, 0.5)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
frame_gaps AS (
  SELECT
    COALESCE(a.display_frame_token, a.surface_frame_token) as frame_id,
    a.ts,
    a.dur,
    a.upid,
    p.name as process_name,
    LAG(a.ts + a.dur) OVER (PARTITION BY a.upid ORDER BY a.ts) as prev_end,
    a.ts - LAG(a.ts + a.dur) OVER (PARTITION BY a.upid ORDER BY a.ts) as gap_ns
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND a.dur > 0
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
session_markers AS (
  SELECT *,
    CASE WHEN gap_ns IS NULL OR gap_ns > (SELECT vsync_period_ns * 6 FROM vsync_config) THEN 1 ELSE 0 END as new_session
  FROM frame_gaps
),
sessions AS (
  SELECT *,
    SUM(new_session) OVER (PARTITION BY upid ORDER BY ts) as session_id
  FROM session_markers
)
SELECT
  session_id,
  process_name,
  printf('%d', MIN(ts)) as start_ts,
  printf('%d', MAX(ts + dur)) as end_ts,
  COUNT(*) as frame_count,
  -- duration_ms is the primary display column (already in ms)
  ROUND((MAX(ts + dur) - MIN(ts)) / 1e6, 1) as duration_ms,
  -- duration in ns as string to avoid 32-bit integer overflow (for downstream consumers)
  printf('%d', MAX(ts + dur) - MIN(ts)) as duration,
  CAST(ROUND(AVG(dur)) AS INTEGER) as avg_dur,
  MAX(dur) as max_dur,
  ROUND(1e9 * COUNT(*) / NULLIF(MAX(ts + dur) - MIN(ts), 0), 1) as session_fps
FROM sessions
GROUP BY upid, session_id
HAVING COUNT(*) >= 10
  AND (MAX(ts + dur) - MIN(ts)) > 200000000
ORDER BY MIN(ts)

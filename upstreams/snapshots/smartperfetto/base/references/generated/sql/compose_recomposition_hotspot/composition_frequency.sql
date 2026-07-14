-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 2895ae93d263a1097b752875bc22c0e4521e6f96b6ad4feb319da03a76a0d59b
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH recomp_events AS (
  SELECT
    s.ts,
    s.dur,
    s.name,
    s.process_name,
    s.upid
  FROM thread_slice s
  WHERE (s.process_name GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
    AND (s.name GLOB 'Recompos*' OR s.name GLOB 'Compose:*' OR s.name GLOB '*CompositionLocal*')
),
trace_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as t_start,
    COALESCE(${end_ts}, MAX(ts + dur)) as t_end
  FROM recomp_events
),
time_windows AS (
  SELECT
    t_start + (value * 1000000000) as window_start,
    t_start + ((value + 1) * 1000000000) as window_end
  FROM trace_bounds
  JOIN (
    WITH RECURSIVE cnt(value) AS (
      SELECT 0
      UNION ALL
      SELECT value + 1 FROM cnt
      WHERE value < 300
    )
    SELECT value FROM cnt
  )
  WHERE t_start + (value * 1000000000) < t_end
)
SELECT
  printf('%d', tw.window_start) as window_ts,
  re.process_name,
  COUNT(re.ts) as recomposition_count,
  ROUND(SUM(re.dur) / 1e6, 2) as total_dur_ms,
  CASE
    WHEN COUNT(re.ts) > 60 THEN '过度重组'
    WHEN COUNT(re.ts) > 30 THEN '频繁重组'
    WHEN COUNT(re.ts) > 10 THEN '正常'
    ELSE '空闲'
  END as status
FROM time_windows tw
LEFT JOIN recomp_events re ON re.ts >= tw.window_start AND re.ts < tw.window_end
WHERE re.process_name IS NOT NULL
GROUP BY tw.window_start, re.process_name
HAVING recomposition_count > 0
ORDER BY recomposition_count DESC
LIMIT 50

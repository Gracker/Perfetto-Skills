-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH observed AS (
  SELECT
    MIN(c.ts) as min_ts,
    MAX(c.ts) as max_ts
  FROM counter c
  LEFT JOIN counter_track ct ON c.track_id = ct.id
  LEFT JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE (
      cct.name = 'cpufreq'
      OR ct.name LIKE '%thermal%'
      OR ct.name LIKE '%temp%'
      OR ct.name LIKE '%temperature%'
      OR ct.name LIKE '%tsens%'
      OR ct.name LIKE '%gpu%'
    )
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
)
SELECT
  CASE
    WHEN COALESCE(${start_ts}, min_ts) IS NOT NULL
      THEN printf('%d', COALESCE(${start_ts}, min_ts))
    ELSE NULL
  END as window_start_ts,
  CASE
    WHEN COALESCE(${end_ts}, max_ts) IS NOT NULL
      THEN printf('%d', COALESCE(${end_ts}, max_ts))
    ELSE NULL
  END as window_end_ts,
  CASE
    WHEN COALESCE(${start_ts}, min_ts) IS NOT NULL
      AND COALESCE(${end_ts}, max_ts) IS NOT NULL
      THEN ROUND((COALESCE(${end_ts}, max_ts) - COALESCE(${start_ts}, min_ts)) / 1e6, 2)
    ELSE NULL
  END as window_ms,
  CASE
    WHEN ${start_ts} IS NOT NULL OR ${end_ts} IS NOT NULL THEN 'user_selected'
    WHEN min_ts IS NOT NULL AND max_ts IS NOT NULL THEN 'auto_observed_range'
    ELSE 'unavailable'
  END as window_source
FROM observed

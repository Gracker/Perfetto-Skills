-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: 847df75d4dff0db6d9e8a10b5d5654d248cc898fde909ce265075dfb85209401
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH trace_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
)
SELECT
  'app' AS lane,
  'UNKNOWN' AS state,
  '未知' AS state_label,
  printf('%d', t_start) AS start_ts,
  printf('%d', t_end) AS end_ts,
  t_end - t_start AS dur_ns,
  CAST((t_end - t_start) / 1000000 AS INT) AS dur_ms,
  'table_missing' AS source_status
FROM trace_bounds

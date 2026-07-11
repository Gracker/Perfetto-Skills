-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: e3ba12b4a53d3c90d152f942c7f910e4108218ef5da2c56c0e19561009686fc2
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH trace_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
)
SELECT
  'device' AS lane,
  'UNKNOWN' AS state,
  '未知' AS state_label,
  printf('%d', t_start) AS start_ts,
  printf('%d', t_end) AS end_ts,
  t_end - t_start AS dur_ns,
  CAST((t_end - t_start) / 1000000 AS INT) AS dur_ms,
  'table_missing' AS source_status
FROM trace_bounds

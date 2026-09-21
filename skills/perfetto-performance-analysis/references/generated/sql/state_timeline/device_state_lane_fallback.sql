-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: fd6c633f728fed86747941747f63d55962479f3073fb5dada8da2116d5ec350b
-- Source commit: bc007586871a720aed82537913617c64fb95a459

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
WITH lane_bounds AS (
  SELECT start_ts AS t_start, end_ts AS t_end FROM trace_bounds
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
FROM lane_bounds
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)

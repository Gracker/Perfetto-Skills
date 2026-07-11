-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  MIN(ts) AS start_ts,
  MAX(ts) AS end_ts,
  printf('%d', MIN(ts)) AS start_ts_str,
  printf('%d', MAX(ts)) AS end_ts_str,
  ROUND((MAX(ts) - MIN(ts)) / 1e9, 2) AS duration_sec
FROM (
  SELECT ts FROM slice WHERE dur > 0
  UNION ALL
  SELECT ts FROM counter WHERE value IS NOT NULL
)

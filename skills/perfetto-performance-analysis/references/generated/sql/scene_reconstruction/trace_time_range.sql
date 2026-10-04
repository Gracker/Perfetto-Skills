-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

SELECT printf('%d', start_ts) AS start_ts, printf('%d', end_ts) AS end_ts,
  printf('%d', start_ts) AS start_ts_str, printf('%d', end_ts) AS end_ts_str,
  ROUND((end_ts - start_ts) / 1e9, 2) AS duration_sec FROM trace_bounds

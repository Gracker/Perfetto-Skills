-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 8832b9e9b6f0bb86a0676bcd50f367546a3406ef8111be90fe60511d26678d5b
-- Source commit: bc007586871a720aed82537913617c64fb95a459

SELECT printf('%d', start_ts) AS start_ts, printf('%d', end_ts) AS end_ts,
  printf('%d', start_ts) AS start_ts_str, printf('%d', end_ts) AS end_ts_str,
  ROUND((end_ts - start_ts) / 1e9, 2) AS duration_sec FROM trace_bounds

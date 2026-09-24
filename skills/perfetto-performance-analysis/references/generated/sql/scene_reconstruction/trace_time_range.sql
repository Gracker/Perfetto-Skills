-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

SELECT printf('%d', start_ts) AS start_ts, printf('%d', end_ts) AS end_ts,
  printf('%d', start_ts) AS start_ts_str, printf('%d', end_ts) AS end_ts_str,
  ROUND((end_ts - start_ts) / 1e9, 2) AS duration_sec FROM trace_bounds

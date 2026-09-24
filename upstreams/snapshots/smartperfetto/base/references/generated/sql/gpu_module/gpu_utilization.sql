-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 6dd740df9f3de46527f96908cf6ac30d71767e6f61d2bc2d6544f825cbbc3551
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  track.name AS metric_name,
  CAST(AVG(value) AS REAL) AS avg_value,
  CAST(MAX(value) AS REAL) AS max_value
FROM counter
JOIN gpu_counter_track track ON counter.track_id = track.id
WHERE track.name LIKE '%util%' OR track.name LIKE '%busy%' OR track.name LIKE '%load%'
GROUP BY track.name

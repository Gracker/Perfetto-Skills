-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 6dd740df9f3de46527f96908cf6ac30d71767e6f61d2bc2d6544f825cbbc3551
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  track.name AS metric_name,
  CAST(AVG(value) AS REAL) AS avg_value,
  CAST(MAX(value) AS REAL) AS max_value
FROM counter
JOIN gpu_counter_track track ON counter.track_id = track.id
WHERE track.name LIKE '%util%' OR track.name LIKE '%busy%' OR track.name LIKE '%load%'
GROUP BY track.name

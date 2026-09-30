-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 192990c452ad55ead1e017ec97c29c577f607f5717020867e352b598e36abbce

SELECT
  track.name AS metric_name,
  CAST(AVG(value) AS REAL) AS avg_value,
  CAST(MAX(value) AS REAL) AS max_value
FROM counter
JOIN gpu_counter_track track ON counter.track_id = track.id
WHERE track.name LIKE '%util%' OR track.name LIKE '%busy%' OR track.name LIKE '%load%'
GROUP BY track.name

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 192990c452ad55ead1e017ec97c29c577f607f5717020867e352b598e36abbce

SELECT
  track.name AS counter_name,
  CAST(AVG(value) AS INTEGER) AS avg_value,
  CAST(MAX(value) AS INTEGER) AS max_value,
  CAST(MIN(value) AS INTEGER) AS min_value
FROM counter
JOIN gpu_counter_track track ON counter.track_id = track.id
WHERE track.name LIKE '%freq%' OR track.name LIKE '%clock%'
GROUP BY track.name

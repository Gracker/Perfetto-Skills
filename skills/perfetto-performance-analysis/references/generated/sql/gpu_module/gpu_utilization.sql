-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: b886833bb0a8ce73f11e481eb087092418db60082fdec57dda4d24dd6c000658

SELECT
  track.name AS metric_name,
  CAST(AVG(value) AS REAL) AS avg_value,
  CAST(MAX(value) AS REAL) AS max_value
FROM counter
JOIN gpu_counter_track track ON counter.track_id = track.id
WHERE track.name LIKE '%util%' OR track.name LIKE '%busy%' OR track.name LIKE '%load%'
GROUP BY track.name

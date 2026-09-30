-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: b1684cac1874ae453391ccfe88614289405b052dad8ab7ec594255347bb37acb

SELECT
  ct.name AS counter_name,
  CAST(MIN(c.value) AS REAL) AS min_value,
  CAST(MAX(c.value) AS REAL) AS max_value,
  CAST(AVG(c.value) AS REAL) AS avg_value,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name GLOB '*power*'
  OR ct.name GLOB '*Power*'
  OR ct.name GLOB '*battery*'
  OR ct.name GLOB '*Battery*'
  OR ct.name GLOB '*current*'
  OR ct.name GLOB '*voltage*'
  OR ct.name GLOB '*energy*'
GROUP BY ct.name
ORDER BY avg_value DESC

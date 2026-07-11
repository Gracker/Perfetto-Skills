-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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

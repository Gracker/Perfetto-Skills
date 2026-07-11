-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: fc8a23df5565689fd067df4b8f2fb32e90a8ddc8f1ca0a7df410f8108cedf708
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  ct.name AS cooling_device,
  CAST(MIN(c.value) AS INTEGER) AS min_level,
  CAST(MAX(c.value) AS INTEGER) AS max_level,
  CAST(AVG(c.value) AS INTEGER) AS avg_level,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name GLOB '*cooling*'
  OR ct.name GLOB '*fan*'
  OR ct.name GLOB '*cdev*'
GROUP BY ct.name
ORDER BY avg_level DESC

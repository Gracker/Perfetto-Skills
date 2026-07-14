-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: fc8a23df5565689fd067df4b8f2fb32e90a8ddc8f1ca0a7df410f8108cedf708
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  ct.name AS sensor_name,
  COUNT(*) AS sample_count,
  CAST(MIN(c.value) AS INTEGER) AS min_temp,
  CAST(MAX(c.value) AS INTEGER) AS max_temp,
  CAST(AVG(c.value) AS INTEGER) AS avg_temp,
  CAST(MAX(c.value) - MIN(c.value) AS INTEGER) AS temp_range,
  CASE
    WHEN MAX(c.value) > 80 THEN 'critical'
    WHEN MAX(c.value) > 70 THEN 'warning'
    WHEN MAX(c.value) > 60 THEN 'elevated'
    ELSE 'normal'
  END AS status
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name GLOB '*thermal*'
  OR ct.name GLOB '*temp*'
  OR ct.name GLOB '*temperature*'
  OR ct.name GLOB '*tsens*'
  OR ct.name GLOB '*Temp*'
GROUP BY ct.name
ORDER BY max_temp DESC

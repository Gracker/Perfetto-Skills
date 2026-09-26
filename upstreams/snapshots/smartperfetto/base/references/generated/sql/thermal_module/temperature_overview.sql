-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: 6125d0a80aa8a0085e13bd9dde675dcd250b22db719a7359f4c54c3503a4fd33
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  ct.id AS sensor_track_id,
  ct.name AS sensor_name,
  ct.unit AS source_unit,
  COUNT(*) AS sample_count,
  CAST(MIN(c.value) AS INTEGER) AS min_temp,
  CAST(MAX(c.value) AS INTEGER) AS max_temp,
  CAST(AVG(c.value) AS INTEGER) AS avg_temp,
  'arithmetic_sample_mean_not_time_weighted' AS aggregation_basis,
  CAST(MAX(c.value) - MIN(c.value) AS INTEGER) AS temp_range,
  CASE
    WHEN ct.unit IS NULL OR ct.unit != 'C' THEN 'unit_unknown_or_unsupported'
    WHEN MAX(c.value) > 80 THEN 'critical'
    WHEN MAX(c.value) > 70 THEN 'warning'
    WHEN MAX(c.value) > 60 THEN 'elevated'
    ELSE 'normal'
  END AS status
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE (ct.name GLOB '*thermal*'
  OR ct.name GLOB '*temp*'
  OR ct.name GLOB '*temperature*'
  OR ct.name GLOB '*tsens*'
  OR ct.name GLOB '*Temp*')
  AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY ct.id, ct.name, ct.unit
ORDER BY max_temp DESC

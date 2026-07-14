-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: fc8a23df5565689fd067df4b8f2fb32e90a8ddc8f1ca0a7df410f8108cedf708
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM counter
),
thermal_samples AS (
  SELECT
    (c.ts - (SELECT start_ts FROM time_range)) / 1e9 as time_sec,
    ct.name as sensor_name,
    c.value as temperature
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE ct.name GLOB '*thermal*'
    OR ct.name GLOB '*temp*'
    OR ct.name GLOB '*temperature*'
)
SELECT
  CAST(time_sec AS INTEGER) as second,
  sensor_name,
  CAST(AVG(temperature) AS INTEGER) as avg_temp,
  CAST(MAX(temperature) AS INTEGER) as max_temp
FROM thermal_samples
GROUP BY CAST(time_sec AS INTEGER), sensor_name
ORDER BY second, sensor_name
LIMIT 300

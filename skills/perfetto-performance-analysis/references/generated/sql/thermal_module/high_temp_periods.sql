-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: fc8a23df5565689fd067df4b8f2fb32e90a8ddc8f1ca0a7df410f8108cedf708
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM counter
),
high_temps AS (
  SELECT
    (c.ts - (SELECT start_ts FROM time_range)) / 1e9 as time_sec,
    ct.name as sensor_name,
    c.value as temperature
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*thermal*' OR ct.name GLOB '*temp*')
    AND c.value > 60
)
SELECT
  sensor_name,
  ROUND(MIN(time_sec), 2) as start_sec,
  ROUND(MAX(time_sec), 2) as end_sec,
  ROUND(MAX(time_sec) - MIN(time_sec), 2) as duration_sec,
  CAST(MAX(temperature) AS INTEGER) as peak_temp,
  CAST(AVG(temperature) AS INTEGER) as avg_temp,
  COUNT(*) as sample_count
FROM high_temps
GROUP BY sensor_name
HAVING COUNT(*) > 1
ORDER BY peak_temp DESC

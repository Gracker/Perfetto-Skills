-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: 6125d0a80aa8a0085e13bd9dde675dcd250b22db719a7359f4c54c3503a4fd33
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM counter
),
high_temps AS (
  SELECT
    (c.ts - (SELECT start_ts FROM time_range)) / 1e9 as time_sec,
    ct.id as sensor_track_id,
    ct.unit as source_unit,
    ct.name as sensor_name,
    c.value as temperature
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*thermal*' OR ct.name GLOB '*temp*')
    AND ct.unit = 'C'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
    AND c.value > 60
)
SELECT
  sensor_track_id,
  sensor_name,
  source_unit,
  ROUND(MIN(time_sec), 2) as start_sec,
  ROUND(MAX(time_sec), 2) as end_sec,
  ROUND(MAX(time_sec) - MIN(time_sec), 2) as duration_sec,
  'first_to_last_high_sample_span_not_continuous_hot_duration' AS duration_basis,
  CAST(MAX(temperature) AS INTEGER) as peak_temp,
  CAST(AVG(temperature) AS INTEGER) as avg_temp,
  'arithmetic_sample_mean_not_time_weighted' AS aggregation_basis,
  COUNT(*) as sample_count
FROM high_temps
GROUP BY sensor_track_id, sensor_name, source_unit
HAVING COUNT(*) > 1
ORDER BY peak_temp DESC

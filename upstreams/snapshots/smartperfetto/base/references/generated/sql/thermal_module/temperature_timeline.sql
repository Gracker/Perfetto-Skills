-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: 6125d0a80aa8a0085e13bd9dde675dcd250b22db719a7359f4c54c3503a4fd33
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM counter
),
thermal_samples AS (
  SELECT
    (c.ts - (SELECT start_ts FROM time_range)) / 1e9 as time_sec,
    ct.id as sensor_track_id,
    ct.unit as source_unit,
    ct.name as sensor_name,
    c.value as temperature
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*thermal*'
    OR ct.name GLOB '*temp*'
    OR ct.name GLOB '*temperature*')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
)
SELECT
  CAST(time_sec AS INTEGER) as second,
  sensor_track_id,
  sensor_name,
  source_unit,
  CAST(AVG(temperature) AS INTEGER) as avg_temp,
  'arithmetic_sample_mean_not_time_weighted' AS aggregation_basis,
  CAST(MAX(temperature) AS INTEGER) as max_temp
FROM thermal_samples
GROUP BY CAST(time_sec AS INTEGER), sensor_track_id, sensor_name, source_unit
ORDER BY second, sensor_name
LIMIT 300

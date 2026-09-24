-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: 6125d0a80aa8a0085e13bd9dde675dcd250b22db719a7359f4c54c3503a4fd33
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM counter
),
thermal_by_sec AS (
  SELECT
    CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER) as second,
    MAX(c.value) as max_temp
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*thermal*' OR ct.name GLOB '*temp*')
    AND ct.unit = 'C'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  GROUP BY CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER)
),
freq_by_sec AS (
  SELECT
    CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER) as second,
    CAST(AVG(c.value / 1000) AS INTEGER) as avg_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  GROUP BY CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER)
)
SELECT
  t.second,
  CAST(t.max_temp AS INTEGER) as max_temp,
  'C' AS source_unit,
  f.avg_freq_mhz,
  'same_second_sample_aggregation_not_causal_or_time_weighted' AS correlation_basis,
  CASE
    WHEN t.max_temp > 70 AND f.avg_freq_mhz < 1500 THEN 'high_temperature_with_low_sampled_frequency'
    WHEN t.max_temp > 60 AND f.avg_freq_mhz < 2000 THEN 'elevated_temperature_with_low_sampled_frequency'
    ELSE 'no_threshold_coincidence'
  END as status
FROM thermal_by_sec t
JOIN freq_by_sec f ON t.second = f.second
ORDER BY t.second
LIMIT 120

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: fc8a23df5565689fd067df4b8f2fb32e90a8ddc8f1ca0a7df410f8108cedf708
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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
  WHERE ct.name GLOB '*thermal*' OR ct.name GLOB '*temp*'
  GROUP BY CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER)
),
freq_by_sec AS (
  SELECT
    CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER) as second,
    CAST(AVG(c.value / 1000) AS INTEGER) as avg_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
  GROUP BY CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER)
)
SELECT
  t.second,
  CAST(t.max_temp AS INTEGER) as max_temp,
  f.avg_freq_mhz,
  CASE
    WHEN t.max_temp > 70 AND f.avg_freq_mhz < 1500 THEN 'thermal_throttled'
    WHEN t.max_temp > 60 AND f.avg_freq_mhz < 2000 THEN 'possible_throttle'
    ELSE 'normal'
  END as status
FROM thermal_by_sec t
JOIN freq_by_sec f ON t.second = f.second
ORDER BY t.second
LIMIT 120

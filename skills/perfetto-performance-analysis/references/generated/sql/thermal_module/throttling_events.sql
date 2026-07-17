-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: fc8a23df5565689fd067df4b8f2fb32e90a8ddc8f1ca0a7df410f8108cedf708
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM counter
),
freq_changes AS (
  SELECT
    cct.cpu as cpu_id,
    (c.ts - (SELECT start_ts FROM time_range)) / 1e9 as time_sec,
    c.value / 1000 as freq_mhz,
    LAG(c.value / 1000) OVER (PARTITION BY cct.cpu ORDER BY c.ts) as prev_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
)
SELECT
  cpu_id,
  ROUND(time_sec, 2) as time_sec,
  CAST(prev_freq_mhz AS INTEGER) as prev_freq_mhz,
  CAST(freq_mhz AS INTEGER) as new_freq_mhz,
  CAST((prev_freq_mhz - freq_mhz) AS INTEGER) as drop_mhz,
  ROUND((prev_freq_mhz - freq_mhz) * 100.0 / prev_freq_mhz, 1) as drop_pct
FROM freq_changes
WHERE prev_freq_mhz IS NOT NULL
  AND freq_mhz < prev_freq_mhz * 0.7
ORDER BY drop_mhz DESC
LIMIT 30

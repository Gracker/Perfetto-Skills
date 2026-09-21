-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: 95a308c02902be7277bd6109628fc67a93014b6f3cedc063e3df00fff0bb4a3e
-- Source commit: bc007586871a720aed82537913617c64fb95a459

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM counter
),
freq_changes AS (
  SELECT
    cct.cpu as cpu_id,
    cct.id as frequency_track_id,
    c.ts as ts,
    (c.ts - (SELECT start_ts FROM time_range)) / 1e9 as time_sec,
    c.value / 1000 as freq_mhz,
    LAG(c.value / 1000) OVER (PARTITION BY cct.id ORDER BY c.ts, c.id) as prev_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
)
SELECT
  cpu_id,
  frequency_track_id,
  ts,
  ROUND(time_sec, 2) as time_sec,
  CAST(prev_freq_mhz AS INTEGER) as prev_freq_mhz,
  CAST(freq_mhz AS INTEGER) as new_freq_mhz,
  CAST((prev_freq_mhz - freq_mhz) AS INTEGER) as drop_mhz,
  ROUND((prev_freq_mhz - freq_mhz) * 100.0 / prev_freq_mhz, 1) as drop_pct
FROM freq_changes
WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
  AND prev_freq_mhz IS NOT NULL
  AND freq_mhz < prev_freq_mhz * 0.7
ORDER BY drop_mhz DESC
LIMIT 30

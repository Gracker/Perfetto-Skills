-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: d4e9863b2759a03fe335ca68987e3e400bc1aa0a503a3b2f711fc6173cae70a6
-- Source commit: bc007586871a720aed82537913617c64fb95a459

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track
    WHERE name LIKE '%thermal%'
       OR name LIKE '%temp%'
       OR name LIKE '%temperature%'
       OR name LIKE '%tsens%'
  ) THEN 1 ELSE 0 END as has_thermal_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM cpu_counter_track WHERE name = 'cpufreq'
  ) THEN 1 ELSE 0 END as has_freq_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'android_gpu_frequency'
  ) THEN 1 ELSE 0 END as has_gpu_freq_data

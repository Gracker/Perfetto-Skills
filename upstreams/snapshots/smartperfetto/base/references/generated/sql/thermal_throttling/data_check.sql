-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

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

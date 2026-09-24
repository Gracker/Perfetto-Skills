-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: 5fad39740c373b463c8080622927249e67de2e731ea1cf79253d443663541c7e
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

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
  ) THEN 1 ELSE 0 END as has_gpu_freq_data,
  -- Direct throttling evidence. A temperature counter correlating with a
  -- low frequency proves nothing; these two do the actual work.
  CASE WHEN EXISTS (
    SELECT 1 FROM cpu_counter_track
    WHERE type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')
  ) THEN 1 ELSE 0 END as has_limit_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track WHERE type = 'cooling_device_counter'
  ) THEN 1 ELSE 0 END as has_cdev_data

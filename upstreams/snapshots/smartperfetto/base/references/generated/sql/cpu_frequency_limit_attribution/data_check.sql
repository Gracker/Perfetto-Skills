-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_attribution.skill.yaml
-- Source SHA-256: 9b27b3315b361c5cd21809d36d2415240a89ae8baf023b849ee3a4a8ba068888
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

SELECT
  CASE WHEN EXISTS (SELECT 1 FROM cpu_counter_track
    WHERE type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit'))
    THEN 1 ELSE 0 END AS has_limit_data,
  CASE WHEN EXISTS (SELECT 1 FROM counter_track WHERE type = 'cooling_device_counter')
    THEN 1 ELSE 0 END AS has_cdev_data,
  CASE WHEN EXISTS (SELECT 1 FROM counter_track WHERE type = 'thermal_temperature')
    THEN 1 ELSE 0 END AS has_temperature_data,
  CASE WHEN EXISTS (SELECT 1 FROM cpu_counter_track WHERE type = 'cpu_frequency')
    THEN 1 ELSE 0 END AS has_cpufreq_data,
  CASE WHEN EXISTS (SELECT 1 FROM sched_slice) THEN 1 ELSE 0 END AS has_sched_data

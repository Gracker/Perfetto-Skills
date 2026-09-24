-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_attribution.skill.yaml
-- Source SHA-256: 9b27b3315b361c5cd21809d36d2415240a89ae8baf023b849ee3a4a8ba068888
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT
  'unavailable' AS limit_evidence,
  'power/cpu_frequency_limits' AS required_ftrace_event,
  'thermal/cdev_update, thermal/thermal_temperature, power/cpu_frequency' AS also_useful,
  '本 trace 没有 cpufreq policy 限频轨道，因此无法直接判断频率是否被限制。观测到的频率低既可能是被限频，也可能只是负载下降或进入空闲 DVFS——两者在没有限频事件时不可区分。请在采集配置的 ftrace_events 中加入 power/cpu_frequency_limits（以及 thermal/cdev_update、thermal/thermal_temperature）后重新采集。' AS message,
  'observation_not_causal' AS evidence_scope

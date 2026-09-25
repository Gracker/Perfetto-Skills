-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_limit_timeline.skill.yaml
-- Source SHA-256: 9ca20ae0bd75e18a790d8f725bc86549da9ef82647525a0180194ab11908877b
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  'unavailable' AS limit_evidence,
  'power/cpu_frequency_limits' AS required_ftrace_event,
  'Trace 中没有 cpufreq policy 限频轨道（cpu_max_frequency_limit / cpu_min_frequency_limit）。缺少该数据时无法直接观测限频，只能观测实际频率，不能据此判断是否被限频。请在采集配置的 ftrace_events 中加入 power/cpu_frequency_limits 后重新采集。' AS message

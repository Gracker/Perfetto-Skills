-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
-- Source SHA-256: 2bfbf5a93acfc357d547823fbb66c86dfb6194896e44f4c338d3a98f941c141b

SELECT
  'unavailable' AS cooling_evidence,
  'thermal/cdev_update' AS required_ftrace_event,
  'Trace 中没有内核 cooling device 轨道，不能据此判断是否发生热控：不少 Qualcomm 平台由用户态 thermal daemon 直接写 cpufreq sysfs 的频率上限，不产生 cdev_update 事件。请改用限频轨道与热控守护进程活动进行判断，或在采集配置中加入 thermal/cdev_update。' AS message

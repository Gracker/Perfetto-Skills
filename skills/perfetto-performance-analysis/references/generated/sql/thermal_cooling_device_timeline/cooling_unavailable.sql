-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
-- Source SHA-256: 212c1203887256c5706a1e12c54ae6d163c0bb8647edd88afb0f73cc624cf16f
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  'unavailable' AS cooling_evidence,
  'thermal/cdev_update' AS required_ftrace_event,
  'Trace 中没有内核 cooling device 轨道。这不代表设备没有发生热控：不少 Qualcomm 平台由用户态 thermal daemon 直接写 cpufreq sysfs 限频，不产生 cdev_update 事件。请改用限频轨道与热控守护进程活动进行判断，或在采集配置中加入 thermal/cdev_update。' AS message

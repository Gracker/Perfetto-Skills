-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: 5fad39740c373b463c8080622927249e67de2e731ea1cf79253d443663541c7e
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT '未检测到温度传感器数据。可能原因：Trace 未包含 thermal/temperature counter，或设备不支持温度上报。建议：确保 Trace 包含 ftrace thermal 事件。' as message

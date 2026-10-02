-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: dad4f0316164e1f40e731c8d36689fa5f09b8972bf70f5a4d48c894df90f3c91

SELECT '未检测到温度传感器数据。可能原因：Trace 未包含 thermal/temperature counter，或设备不支持温度上报。建议：确保 Trace 包含 ftrace thermal 事件。' as message

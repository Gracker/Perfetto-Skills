-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: d8d420f2d0c8b12433ba27443f712124525100e866e03333420cc2bcbde623b8

SELECT '未检测到温度传感器数据。可能原因：Trace 未包含 thermal/temperature counter，或设备不支持温度上报。建议：确保 Trace 包含 ftrace thermal 事件。' as message

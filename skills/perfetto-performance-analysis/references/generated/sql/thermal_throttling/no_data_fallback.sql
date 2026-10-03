-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: 03d5214cde82b7f701aaf49433f9e9dd86053d0c50cd7845247da2506662c32e

SELECT '未检测到温度传感器数据。可能原因：Trace 未包含 thermal/temperature counter，或设备不支持温度上报。建议：确保 Trace 包含 ftrace thermal 事件。' as message

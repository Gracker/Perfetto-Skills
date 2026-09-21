-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: d4e9863b2759a03fe335ca68987e3e400bc1aa0a503a3b2f711fc6173cae70a6
-- Source commit: bc007586871a720aed82537913617c64fb95a459

SELECT '未检测到温度传感器数据。可能原因：Trace 未包含 thermal/temperature counter，或设备不支持温度上报。建议：确保 Trace 包含 ftrace thermal 事件。' as message

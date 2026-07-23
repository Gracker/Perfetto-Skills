-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT '未检测到温度传感器数据。可能原因：Trace 未包含 thermal/temperature counter，或设备不支持温度上报。建议：确保 Trace 包含 ftrace thermal 事件。' as message

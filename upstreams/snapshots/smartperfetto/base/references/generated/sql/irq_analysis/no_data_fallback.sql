-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: f009fd41aa9f0a562da268c17227701662484f515d5399de8137df35dc9cf21d
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT '未检测到 IRQ 中断数据。可能原因：Trace 未启用 ftrace irq 事件 (irq/softirq)。建议：录制时启用 irq/irq_handler_entry/softirq_entry 等 ftrace 事件。' as message

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: f009fd41aa9f0a562da268c17227701662484f515d5399de8137df35dc9cf21d
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

SELECT '未检测到 IRQ 中断数据。可能原因：Trace 未启用 ftrace irq 事件 (irq/softirq)。建议：录制时启用 irq/irq_handler_entry/softirq_entry 等 ftrace 事件。' as message

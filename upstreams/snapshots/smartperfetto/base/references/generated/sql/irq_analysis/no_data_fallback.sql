-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: fea29723032ba827d7c7b294e22ea8ff4633c9c6e8abb832895f9a9642a6e595

SELECT '未检测到 IRQ 中断数据。可能原因：Trace 未启用 ftrace irq 事件 (irq/softirq)。建议：录制时启用 irq/irq_handler_entry/softirq_entry 等 ftrace 事件。' as message

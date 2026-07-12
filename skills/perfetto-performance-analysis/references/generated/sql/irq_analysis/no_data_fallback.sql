-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 01c95791e727e794914309ad6d43a4c1031919d195ae01d52f20ce5420d70576
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT '未检测到 IRQ 中断数据。可能原因：Trace 未启用 ftrace irq 事件 (irq/softirq)。建议：录制时启用 irq/irq_handler_entry/softirq_entry 等 ftrace 事件。' as message

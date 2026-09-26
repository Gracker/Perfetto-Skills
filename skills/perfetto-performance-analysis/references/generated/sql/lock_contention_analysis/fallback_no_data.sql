-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  '未检测到锁竞争数据' AS status,
  '请确认 Trace 启用了 android.monitor_contention 模块，且应用存在 synchronized 锁操作' AS suggestion

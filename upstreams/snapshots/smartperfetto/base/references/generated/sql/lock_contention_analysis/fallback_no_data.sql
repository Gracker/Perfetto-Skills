-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

SELECT
  '未检测到锁竞争数据' AS status,
  '请确认 Trace 启用了 android.monitor_contention 模块，且应用存在 synchronized 锁操作' AS suggestion

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

SELECT
  '未检测到锁竞争数据' AS status,
  '请确认 Trace 启用了 android.monitor_contention 模块，且应用存在 synchronized 锁操作' AS suggestion

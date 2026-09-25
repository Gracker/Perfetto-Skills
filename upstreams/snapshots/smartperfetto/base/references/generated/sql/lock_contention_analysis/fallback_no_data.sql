-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  '未检测到锁竞争数据' AS status,
  '请确认 Trace 启用了 android.monitor_contention 模块，且应用存在 synchronized 锁操作' AS suggestion

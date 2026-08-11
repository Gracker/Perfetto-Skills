-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

SELECT
  s.name AS wakeup_source,
  COUNT(*) AS wakeup_count,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_dur_ms
FROM slice s
WHERE s.name GLOB '*wakeup*'
  OR s.name GLOB '*wake_source*'
  OR s.name GLOB '*irq*wake*'
  OR s.name GLOB '*alarm*'
GROUP BY s.name
ORDER BY wakeup_count DESC
LIMIT 15

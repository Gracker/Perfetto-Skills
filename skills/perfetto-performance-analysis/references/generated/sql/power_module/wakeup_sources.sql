-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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

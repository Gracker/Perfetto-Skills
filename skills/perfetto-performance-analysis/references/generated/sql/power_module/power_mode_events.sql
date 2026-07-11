-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  s.ts,
  s.name AS mode_event,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms
FROM slice s
WHERE s.name GLOB '*battery*saver*'
  OR s.name GLOB '*power*mode*'
  OR s.name GLOB '*performance*mode*'
  OR s.name GLOB '*doze*'
  OR s.name GLOB '*Doze*'
  OR s.name GLOB '*standby*'
ORDER BY s.ts
LIMIT 30

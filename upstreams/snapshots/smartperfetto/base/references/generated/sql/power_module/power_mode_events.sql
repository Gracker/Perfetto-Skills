-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

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

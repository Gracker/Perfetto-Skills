-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  s.ts,
  s.name AS event_type,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms
FROM slice s
WHERE s.name GLOB '*suspend*'
  OR s.name GLOB '*resume*'
  OR s.name GLOB '*Suspend*'
  OR s.name GLOB '*Resume*'
  OR s.name GLOB '*SUSPEND*'
  OR s.name GLOB '*RESUME*'
  OR s.name GLOB '*sleep*'
  OR s.name GLOB '*wakeup*'
ORDER BY s.ts
LIMIT 50

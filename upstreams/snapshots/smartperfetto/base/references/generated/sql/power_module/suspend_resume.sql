-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: b1684cac1874ae453391ccfe88614289405b052dad8ab7ec594255347bb37acb

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: cd2beb4f76696242a572e25220b5f4bfb755d932498796fb7b3098dd5759ec18

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

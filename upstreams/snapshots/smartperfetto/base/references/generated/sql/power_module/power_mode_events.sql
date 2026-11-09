-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: cd2beb4f76696242a572e25220b5f4bfb755d932498796fb7b3098dd5759ec18

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

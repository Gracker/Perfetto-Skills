-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: cd2beb4f76696242a572e25220b5f4bfb755d932498796fb7b3098dd5759ec18

SELECT
  s.name AS wakelock_event,
  COUNT(*) AS event_count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS INTEGER) AS max_ms
FROM slice s
WHERE s.name GLOB '*wakelock*'
  OR s.name GLOB '*Wakelock*'
  OR s.name GLOB '*WAKE_LOCK*'
  OR s.name GLOB '*PowerManager*'
  OR s.name GLOB '*acquire*wake*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 20

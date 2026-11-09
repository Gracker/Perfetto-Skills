-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: cd2beb4f76696242a572e25220b5f4bfb755d932498796fb7b3098dd5759ec18

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

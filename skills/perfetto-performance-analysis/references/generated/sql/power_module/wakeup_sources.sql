-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: b1684cac1874ae453391ccfe88614289405b052dad8ab7ec594255347bb37acb

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: cd2beb4f76696242a572e25220b5f4bfb755d932498796fb7b3098dd5759ec18

SELECT
  ct.name AS idle_state,
  CAST(MIN(c.value) AS INTEGER) AS min_value,
  CAST(MAX(c.value) AS INTEGER) AS max_value,
  CAST(AVG(c.value) AS INTEGER) AS avg_value,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name GLOB '*idle*'
  OR ct.name GLOB '*Idle*'
  OR ct.name GLOB '*cpuidle*'
  OR ct.name GLOB '*C-state*'
GROUP BY ct.name
ORDER BY avg_value DESC

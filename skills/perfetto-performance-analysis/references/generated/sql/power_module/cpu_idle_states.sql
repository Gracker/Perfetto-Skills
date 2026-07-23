-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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

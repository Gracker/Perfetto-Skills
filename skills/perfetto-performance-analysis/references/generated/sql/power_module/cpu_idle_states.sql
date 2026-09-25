-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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

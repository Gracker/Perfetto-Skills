-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: 95a308c02902be7277bd6109628fc67a93014b6f3cedc063e3df00fff0bb4a3e
-- Source commit: bc007586871a720aed82537913617c64fb95a459

SELECT
  ct.name AS cooling_device,
  CAST(MIN(c.value) AS INTEGER) AS min_level,
  CAST(MAX(c.value) AS INTEGER) AS max_level,
  CAST(AVG(c.value) AS INTEGER) AS avg_level,
  'arithmetic_sample_mean_not_time_weighted' AS aggregation_basis,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE (ct.name GLOB '*cooling*'
  OR ct.name GLOB '*fan*'
  OR ct.name GLOB '*cdev*')
  AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY ct.name
ORDER BY avg_level DESC

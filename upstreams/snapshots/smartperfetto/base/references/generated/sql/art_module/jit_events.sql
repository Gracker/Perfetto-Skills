-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: d1467599deb13369b60c04f0f0e38ee4ce36e11b4e96df90b7f409300d451d3f
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  slice.name AS jit_event,
  COUNT(*) AS event_count,
  CAST(SUM(slice.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(slice.dur) / 1e6 AS REAL) AS avg_ms
FROM slice
WHERE slice.name LIKE '%JIT%'
  OR slice.name LIKE '%compile%'
GROUP BY slice.name
ORDER BY total_ms DESC

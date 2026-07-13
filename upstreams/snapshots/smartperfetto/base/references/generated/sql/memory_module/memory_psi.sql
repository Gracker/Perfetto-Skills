-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 4554575145483d31969e45a7f620e2babcd548a6287d30687a303389845885bd
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  ct.name AS psi_type,
  CAST(AVG(c.value) AS REAL) AS avg_value,
  CAST(MAX(c.value) AS REAL) AS max_value,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name GLOB '*psi*'
  OR ct.name GLOB '*PSI*'
  OR ct.name GLOB '*pressure*'
GROUP BY ct.name
ORDER BY avg_value DESC

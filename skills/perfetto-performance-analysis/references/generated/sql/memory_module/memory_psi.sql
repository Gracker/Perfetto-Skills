-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 4554575145483d31969e45a7f620e2babcd548a6287d30687a303389845885bd
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

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

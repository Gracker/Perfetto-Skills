-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: b987a26840357de829425e1b7deba3e412dee91d2541ade4ad72e4866c5c38ff

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: f00717aba46f44cda52a71b3aac619d9a3dabf1eea6b54e5757a38a480c000bc

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

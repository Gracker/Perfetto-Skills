-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 414d1472ca7ef5f999ad8066cb1322622316c622e4bb29e5d0ce7f7b0e4fad9b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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

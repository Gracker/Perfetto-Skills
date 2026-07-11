-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 4554575145483d31969e45a7f620e2babcd548a6287d30687a303389845885bd
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  ct.name AS fault_type,
  CAST(SUM(c.value) AS INTEGER) AS total_faults,
  CAST(AVG(c.value) AS REAL) AS avg_per_sample,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name GLOB '*fault*'
  OR ct.name GLOB '*pgfault*'
  OR ct.name GLOB '*page*fault*'
GROUP BY ct.name
ORDER BY total_faults DESC

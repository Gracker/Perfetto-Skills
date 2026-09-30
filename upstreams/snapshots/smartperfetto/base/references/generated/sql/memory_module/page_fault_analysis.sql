-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: b987a26840357de829425e1b7deba3e412dee91d2541ade4ad72e4866c5c38ff

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

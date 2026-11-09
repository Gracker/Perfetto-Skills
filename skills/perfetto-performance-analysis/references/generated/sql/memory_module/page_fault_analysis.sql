-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: f00717aba46f44cda52a71b3aac619d9a3dabf1eea6b54e5757a38a480c000bc

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

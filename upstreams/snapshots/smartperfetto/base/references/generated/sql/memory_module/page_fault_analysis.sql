-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: c4d29f5ee21c06081cc03ddeefcc79718e488db294e4623000e124ce9c292f0b

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

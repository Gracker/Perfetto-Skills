-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_detection.skill.yaml
-- Source SHA-256: 539074112cd1527ea174f211bee7834c523e137e7c052281ce81e1a3832ca6d0
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  cpu_id as cpu,
  max_freq as max_freq_khz,
  core_type as cluster_type,
  CASE
    WHEN core_type IN ('prime', 'big', 'medium') THEN 'big'
    WHEN core_type = 'little' THEN 'little'
    ELSE 'unknown'
  END as simple_cluster_type,
  topology_source
FROM _cpu_topology
ORDER BY cpu_id

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_detection.skill.yaml
-- Source SHA-256: 539074112cd1527ea174f211bee7834c523e137e7c052281ce81e1a3832ca6d0
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  core_type as cluster_type,
  COUNT(*) as cpu_count,
  GROUP_CONCAT(cpu_id, ', ') as cpus,
  CASE WHEN MAX(max_freq) IS NULL THEN NULL ELSE ROUND(MAX(max_freq) / 1000.0, 0) END as max_freq_mhz,
  CASE WHEN MIN(max_freq) IS NULL THEN NULL ELSE ROUND(MIN(max_freq) / 1000.0, 0) END as min_freq_mhz,
  GROUP_CONCAT(DISTINCT topology_source) as topology_source,
  CASE core_type
    WHEN 'prime' THEN 1
    WHEN 'big' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'little' THEN 4
    ELSE 5
  END as cluster_order
FROM _cpu_topology
GROUP BY core_type
ORDER BY cluster_order

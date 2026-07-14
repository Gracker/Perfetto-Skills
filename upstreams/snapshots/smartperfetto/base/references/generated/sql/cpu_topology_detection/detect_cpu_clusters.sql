-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_detection.skill.yaml
-- Source SHA-256: 539074112cd1527ea174f211bee7834c523e137e7c052281ce81e1a3832ca6d0
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  cpu_id as cpu,
  core_type as cluster_type,
  CASE WHEN max_freq IS NULL THEN NULL ELSE ROUND(max_freq / 1000.0, 0) END as max_freq_mhz,
  capacity,
  topology_source,
  cluster_rank,
  cluster_count,
  CASE core_type
    WHEN 'prime' THEN '超大核'
    WHEN 'big' THEN '大核'
    WHEN 'medium' THEN '中核'
    WHEN 'little' THEN '小核'
    ELSE '未知'
  END as cluster_type_cn
FROM _cpu_topology
ORDER BY
  CASE core_type
    WHEN 'prime' THEN 1
    WHEN 'big' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'little' THEN 4
    ELSE 5
  END,
  cpu_id

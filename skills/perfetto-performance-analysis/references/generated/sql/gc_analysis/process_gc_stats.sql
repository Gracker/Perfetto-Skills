-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 9953952ad063229e1a5f04d58a41962bce74d74d1c303ca177cb7055c0afb366
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  process.name AS process_name,
  ROUND(s.heap_size_mb, 2) AS heap_size_mb,
  ROUND(s.heap_allocation_rate, 2) AS alloc_rate_mb_per_sec,
  ROUND(s.heap_utilization, 3) AS heap_utilization,
  ROUND(s.gc_running_dur / 1e9, 3) AS gc_cpu_sec,
  ROUND(s.gc_running_rate * 100, 2) AS gc_cpu_pct,
  ROUND(s.gc_running_efficiency, 3) AS gc_running_efficiency
FROM _android_garbage_collection_process_stats s
JOIN process ON s.upid = process.upid
WHERE CASE WHEN '${package}' != ''
           THEN process.name GLOB '*${package}*'
           ELSE 1 END
ORDER BY gc_cpu_sec DESC

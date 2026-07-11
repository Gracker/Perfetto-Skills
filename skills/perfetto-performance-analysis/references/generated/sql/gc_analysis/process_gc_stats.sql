-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 94563f8717669e993b92723f09bb10688c8a9ac9d9c9caf91391ddf4ecf14639
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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

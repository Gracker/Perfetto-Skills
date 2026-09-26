-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 7fe3eb2595b5f8920c8da24ca631b91a13f1e04ac0fe3dda1f3efae096b3319b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
           THEN (process.name = '${package}' OR process.name GLOB '${package}:*')
           ELSE 1 END
ORDER BY gc_cpu_sec DESC

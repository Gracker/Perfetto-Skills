-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 55ba35f956b88823c9a3ffe665eaf555f382cf899a866b669ae5a7011ec4c639
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH
process_cpu AS (
  SELECT
    p.name as process_name,
    p.pid,
    SUM(ss.dur) / 1e6 as cpu_time_ms,
    COUNT(*) as slice_count,
    COUNT(DISTINCT ss.cpu) as cpus_used
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE
    ss.dur > ${min_runtime_ms} * 1e6
    AND ('${package}' = '' OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*'))
  GROUP BY p.upid
)
SELECT
  process_name,
  pid,
  ROUND(cpu_time_ms, 2) as cpu_time_ms,
  slice_count,
  cpus_used,
  ROUND(cpu_time_ms / slice_count, 2) as avg_slice_ms
FROM process_cpu
ORDER BY cpu_time_ms DESC
LIMIT 15

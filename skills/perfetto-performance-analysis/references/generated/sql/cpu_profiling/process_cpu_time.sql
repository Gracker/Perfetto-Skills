-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: a6a66506443dbaafa5b0ec8d01520c945065aa40ce65d0f89fd60577ae67e1ce
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
    AND ('${package}' = '' OR p.name GLOB '${package}*')
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

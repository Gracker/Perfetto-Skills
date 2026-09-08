-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 55ba35f956b88823c9a3ffe665eaf555f382cf899a866b669ae5a7011ec4c639
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
thread_cpu AS (
  SELECT
    t.name as thread_name,
    t.tid,
    p.name as process_name,
    SUM(ss.dur) / 1e6 as cpu_time_ms,
    COUNT(*) as slice_count,
    AVG(ss.dur) / 1e6 as avg_slice_ms
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE
    ss.dur > ${min_runtime_ms} * 1e6
    AND ('${package}' = '' OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*'))
  GROUP BY ss.utid
)
SELECT
  thread_name,
  tid,
  process_name,
  ROUND(cpu_time_ms, 2) as cpu_time_ms,
  slice_count,
  ROUND(avg_slice_ms, 3) as avg_slice_ms
FROM thread_cpu
ORDER BY cpu_time_ms DESC
LIMIT 20

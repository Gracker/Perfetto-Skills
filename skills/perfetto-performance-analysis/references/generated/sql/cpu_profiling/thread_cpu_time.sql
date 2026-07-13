-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

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
    AND ('${package}' = '' OR p.name GLOB '${package}*')
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

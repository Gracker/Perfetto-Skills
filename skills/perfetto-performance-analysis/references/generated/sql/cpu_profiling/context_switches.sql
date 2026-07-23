-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH
context_switch_count AS (
  SELECT
    t.name as thread_name,
    t.tid,
    p.name as process_name,
    COUNT(*) as switch_count,
    SUM(ss.dur) / 1e6 as total_runtime_ms
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE '${package}' = '' OR p.name GLOB '${package}*'
  GROUP BY ss.utid
)
SELECT
  thread_name,
  tid,
  process_name,
  switch_count,
  ROUND(total_runtime_ms, 2) as runtime_ms,
  ROUND(switch_count * 1000.0 / NULLIF(total_runtime_ms, 0), 1) as switches_per_sec
FROM context_switch_count
WHERE switch_count > 10
ORDER BY switches_per_sec DESC
LIMIT 20

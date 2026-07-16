-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
cpu_info AS (
  SELECT cpu_id, core_type
  FROM _cpu_topology
),
thread_core_usage AS (
  SELECT
    t.name as thread_name,
    t.tid,
    p.name as process_name,
    ci.core_type,
    SUM(ss.dur) / 1e6 as runtime_ms
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  JOIN cpu_info ci ON ss.cpu = ci.cpu_id
  WHERE
    ss.dur > ${min_runtime_ms} * 1e6
    AND ('${package}' = '' OR p.name GLOB '${package}*')
  GROUP BY ss.utid, ci.core_type
),
thread_totals AS (
  SELECT
    thread_name,
    tid,
    process_name,
    SUM(runtime_ms) as total_runtime_ms,
    SUM(CASE WHEN core_type IN ('prime', 'big') THEN runtime_ms ELSE 0 END) as big_core_ms,
    SUM(CASE WHEN core_type = 'medium' THEN runtime_ms ELSE 0 END) as medium_core_ms,
    SUM(CASE WHEN core_type = 'little' THEN runtime_ms ELSE 0 END) as little_core_ms
  FROM thread_core_usage
  GROUP BY tid
)
SELECT
  thread_name,
  tid,
  process_name,
  ROUND(total_runtime_ms, 2) as total_ms,
  ROUND(big_core_ms * 100.0 / total_runtime_ms, 1) as big_core_pct,
  ROUND(medium_core_ms * 100.0 / total_runtime_ms, 1) as medium_core_pct,
  ROUND(little_core_ms * 100.0 / total_runtime_ms, 1) as little_core_pct
FROM thread_totals
WHERE total_runtime_ms > 10  -- 至少 10ms 运行时间
ORDER BY total_runtime_ms DESC
LIMIT 20

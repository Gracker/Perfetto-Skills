-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 699bfcd94061182a739f66e7415ec83128b5f61d0efaa9893dacf2f69442f699

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
    COALESCE(ci.core_type, 'unknown') as core_type,
    SUM(ss.dur) / 1e6 as runtime_ms
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN cpu_info ci ON ss.cpu = ci.cpu_id
  WHERE
    ss.dur > ${min_runtime_ms} * 1e6
    AND ('${package}' = '' OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*'))
  GROUP BY ss.utid, ci.core_type
),
thread_totals AS (
  SELECT
    thread_name,
    tid,
    process_name,
    SUM(runtime_ms) as total_runtime_ms,
    SUM(CASE WHEN core_type IN ('prime', 'big', 'medium') THEN runtime_ms ELSE 0 END) as big_core_ms,
    SUM(CASE WHEN core_type = 'medium' THEN runtime_ms ELSE 0 END) as medium_core_ms,
    SUM(CASE WHEN core_type = 'little' THEN runtime_ms ELSE 0 END) as little_core_ms,
    SUM(CASE WHEN core_type NOT IN ('prime', 'big', 'medium', 'little') THEN runtime_ms ELSE 0 END) as unknown_core_ms
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
  ROUND(little_core_ms * 100.0 / total_runtime_ms, 1) as little_core_pct,
  ROUND(unknown_core_ms * 100.0 / total_runtime_ms, 1) as unknown_core_pct,
  -- Unrounded: the conclusion admits a thread only when none of its time is unclassified.
  unknown_core_ms,
  -- Declares the rollup to snapshot comparison (prime+big-only before @2).
  'core_tier_group:prime+big+medium@2' as big_core_pct_definition
FROM thread_totals
WHERE total_runtime_ms > 10  -- 至少 10ms 运行时间
ORDER BY total_runtime_ms DESC
LIMIT 20

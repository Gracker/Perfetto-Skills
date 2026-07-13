-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/task_migration_in_range.skill.yaml
-- Source SHA-256: 1b05bdb3c94d10130b9a0a89dc4e197560e6c66e235eca7924f7b6fe80d9df88
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
target_threads AS (
  SELECT t.utid, t.name as thread_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (t.tid = p.pid OR t.name = 'RenderThread')
),
cpu_switches AS (
  SELECT
    tt.thread_name,
    ts.cpu,
    ct.core_type,
    LAG(ts.cpu) OVER (PARTITION BY tt.utid ORDER BY ts.ts) as prev_cpu,
    LAG(ct.core_type) OVER (PARTITION BY tt.utid ORDER BY ts.ts) as prev_core_type,
    ts.dur
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts >= ${start_ts} AND ts.ts < ${end_ts}
    AND ts.state = 'Running'
)
SELECT
  thread_name,
  SUM(CASE WHEN cpu != prev_cpu AND prev_cpu IS NOT NULL THEN 1 ELSE 0 END) as migration_count,
  SUM(CASE WHEN core_type = 'little' AND prev_core_type = 'big' THEN 1 ELSE 0 END) as big_to_little,
  SUM(CASE WHEN core_type = 'big' AND prev_core_type = 'little' THEN 1 ELSE 0 END) as little_to_big,
  ROUND(100.0 * SUM(CASE WHEN core_type = 'big' THEN dur ELSE 0 END) / NULLIF(SUM(dur), 0), 1) as big_core_pct,
  COUNT(DISTINCT cpu) as unique_cpus
FROM cpu_switches
GROUP BY thread_name
HAVING migration_count > 0
ORDER BY migration_count DESC

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/system_load_in_range.skill.yaml
-- Source SHA-256: 34013d7fab4cc44f7b9247884e5eedbc9c1d4c6d9a60097fb27a1348815a88bb
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH time_range AS (
  SELECT ${end_ts} - ${start_ts} as duration_ns
),
cpu_stats AS (
  SELECT
    SUM(CASE WHEN state = 'Running' THEN dur ELSE 0 END) as running_ns,
    SUM(dur) as total_ns,
    COUNT(DISTINCT cpu) as cpu_count
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  WHERE ts.ts >= ${start_ts} AND ts.ts < ${end_ts}
),
process_stats AS (
  SELECT COUNT(DISTINCT p.upid) as active_processes
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ts.ts >= ${start_ts} AND ts.ts < ${end_ts}
    AND ts.state = 'Running'
),
runnable_stats AS (
  SELECT
    SUM(dur) as total_runnable_ns,
    COUNT(*) as runnable_count
  FROM thread_state
  WHERE ts >= ${start_ts} AND ts < ${end_ts}
    AND state = 'R'
    AND dur > 1000000  -- > 1ms
)
SELECT 'CPU 利用率' as metric,
  ROUND(100.0 * running_ns / NULLIF(total_ns, 0), 1) || '%' as value
FROM cpu_stats
UNION ALL
SELECT 'CPU 核心数' as metric,
  CAST(cpu_count AS TEXT) as value
FROM cpu_stats
UNION ALL
SELECT '活跃进程数' as metric,
  CAST(active_processes AS TEXT) as value
FROM process_stats
UNION ALL
SELECT '长等待事件数' as metric,
  CAST(runnable_count AS TEXT) || ' (>' || ROUND(total_runnable_ns / 1e6, 1) || 'ms total)' as value
FROM runnable_stats
UNION ALL
SELECT '分析时长' as metric,
  ROUND((SELECT duration_ns FROM time_range) / 1e6, 2) || 'ms' as value

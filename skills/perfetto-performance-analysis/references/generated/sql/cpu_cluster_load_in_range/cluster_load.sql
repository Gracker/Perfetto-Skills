-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_cluster_load_in_range.skill.yaml
-- Source SHA-256: 531fd3145d1a67a1ae02e1e028280f2e0e627b4bde1f7c832a985911391fd433
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH
-- 获取每个 CPU 上的 Running 状态时间
cpu_running AS (
  SELECT
    ts.cpu,
    ct.core_type as cluster_type,
    -- 裁剪 slice 到时间范围内
    MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts}) as clipped_dur
  FROM thread_state ts
  JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
    AND ts.state = 'Running'
    AND ts.cpu IS NOT NULL
),
-- 按 CPU 聚合
per_cpu_stats AS (
  SELECT
    cpu,
    cluster_type,
    SUM(CASE WHEN clipped_dur > 0 THEN clipped_dur ELSE 0 END) as running_ns
  FROM cpu_running
  GROUP BY cpu, cluster_type
),
-- 按簇聚合
cluster_stats AS (
  SELECT
    cluster_type,
    COUNT(DISTINCT cpu) as core_count,
    SUM(running_ns) as total_running_ns,
    MAX(running_ns) as max_core_running_ns
  FROM per_cpu_stats
  GROUP BY cluster_type
)
SELECT
  CASE
    WHEN cluster_type = 'big' THEN '大核簇'
    ELSE '小核簇'
  END as cluster,
  core_count,
  ROUND(total_running_ns / 1e6, 2) as running_ms,
  ROUND((${end_ts} - ${start_ts}) * core_count / 1e6, 2) as total_capacity_ms,
  ROUND(100.0 * total_running_ns / NULLIF((${end_ts} - ${start_ts}) * core_count, 0), 1) as load_pct,
  ROUND(100.0 - 100.0 * total_running_ns / NULLIF((${end_ts} - ${start_ts}) * core_count, 0), 1) as idle_pct,
  ROUND(100.0 * max_core_running_ns / NULLIF(${end_ts} - ${start_ts}, 0), 1) as max_single_core_pct
FROM cluster_stats
ORDER BY cluster_type DESC

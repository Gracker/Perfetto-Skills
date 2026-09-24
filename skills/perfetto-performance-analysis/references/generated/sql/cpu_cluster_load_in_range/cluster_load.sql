-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_cluster_load_in_range.skill.yaml
-- Source SHA-256: eb2b4612a94cf363df5045d9d2a8f55599a90a2533d2de33465aae42238aee58
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

WITH
-- 分母 = 簇内全部核心 × 窗口内非挂起时长（与上游 7af4ec945c 同法）。
-- to_monotonic 不计挂起时间；无时钟快照或结果越界时回退到墙钟时长。
awake AS (
  SELECT IIF(monotonic_ns > 0 AND monotonic_ns <= wall_ns, monotonic_ns, wall_ns) AS awake_ns
  FROM (
    SELECT
      ${end_ts} - ${start_ts} AS wall_ns,
      to_monotonic(${end_ts}) - to_monotonic(${start_ts}) AS monotonic_ns
  )
),
-- 核心数取自 _cpu_topology（trace 中实际出现过的核心），不再只数窗口内跑过任务的核心
cluster_cores AS (
  SELECT core_type AS cluster_type, COUNT(DISTINCT cpu_id) AS core_count
  FROM _cpu_topology
  GROUP BY core_type
),
cpu_running AS (
  SELECT
    ts.cpu,
    ct.core_type AS cluster_type,
    MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts}) AS clipped_dur
  FROM thread_state ts
  JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
    AND ts.state = 'Running'
    AND ts.cpu IS NOT NULL
),
per_cpu_stats AS (
  SELECT
    cpu,
    cluster_type,
    SUM(CASE WHEN clipped_dur > 0 THEN clipped_dur ELSE 0 END) AS running_ns
  FROM cpu_running
  GROUP BY cpu, cluster_type
),
cluster_stats AS (
  SELECT
    cc.cluster_type,
    cc.core_count,
    COUNT(pcs.cpu) AS active_core_count,
    COALESCE(SUM(pcs.running_ns), 0) AS total_running_ns,
    COALESCE(MAX(pcs.running_ns), 0) AS max_core_running_ns
  FROM cluster_cores cc
  LEFT JOIN per_cpu_stats pcs ON pcs.cluster_type = cc.cluster_type
  GROUP BY cc.cluster_type, cc.core_count
)
SELECT
  CASE cs.cluster_type
    WHEN 'prime' THEN '超大核簇'
    WHEN 'big' THEN '大核簇'
    WHEN 'medium' THEN '中核簇'
    WHEN 'little' THEN '小核簇'
    ELSE '未分类核心'
  END AS cluster,
  cs.core_count,
  cs.active_core_count,
  ROUND(a.awake_ns / 1e6, 2) AS awake_ms,
  ROUND(cs.total_running_ns / 1e6, 2) AS running_ms,
  ROUND(a.awake_ns * cs.core_count / 1e6, 2) AS total_capacity_ms,
  ROUND(100.0 * cs.total_running_ns / NULLIF(a.awake_ns * cs.core_count, 0), 1) AS load_pct,
  ROUND(100.0 - 100.0 * cs.total_running_ns / NULLIF(a.awake_ns * cs.core_count, 0), 1) AS idle_pct,
  ROUND(100.0 * cs.max_core_running_ns / NULLIF(a.awake_ns, 0), 1) AS max_single_core_pct
FROM cluster_stats cs
CROSS JOIN awake a
ORDER BY CASE cs.cluster_type
  WHEN 'prime' THEN 0 WHEN 'big' THEN 1 WHEN 'medium' THEN 2 WHEN 'little' THEN 3 ELSE 4
END

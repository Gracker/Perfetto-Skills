-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_cluster_load_in_range.skill.yaml
-- Source SHA-256: aa2f4145af6db47f2b6928a496e665965dc44b69e487030be44ae5115b4d8054
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Per-tier CPU cluster load over [${start_ts}, ${end_ts}], shared by
-- cpu_cluster_load_in_range and jank_frame_detail's root cause so their numbers
-- agree (cpu_load_in_range still reports its own per-machine sched measure).
-- Requires _cpu_topology: run the cpu_topology_view Skill first in the same
-- Skill. Denominator follows upstream
-- android_cpu_cluster_utilization_in_interval (7af4ec945c):
--   - every core of the tier in _cpu_topology, not only cores that ran a task
--     in the window (idle cores leaving the denominator overstate the load);
--   - awake time: to_monotonic excludes suspend; without a clock snapshot, or
--     when the result is out of range, the wall-clock duration is used.
-- Running time comes from thread_state, which carries no idle-thread rows; a
-- row still running at trace end (dur = -1) runs to the trace end.
cpu_cluster_awake AS (
  SELECT IIF(monotonic_ns > 0 AND monotonic_ns <= wall_ns, monotonic_ns, wall_ns) AS awake_ns
  FROM (
    SELECT
      ${end_ts} - ${start_ts} AS wall_ns,
      to_monotonic(${end_ts}) - to_monotonic(${start_ts}) AS monotonic_ns
  )
),
cpu_cluster_core_running AS (
  SELECT
    cpu,
    core_type,
    SUM(MIN(end_ts, ${end_ts}) - MAX(ts, ${start_ts})) AS running_ns
  FROM (
    SELECT
      ts.cpu,
      ct.core_type,
      ts.ts,
      IIF(ts.dur < 0, (SELECT end_ts FROM trace_bounds), ts.ts + ts.dur) AS end_ts
    FROM thread_state ts
    JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
    WHERE ts.ts < ${end_ts}
      AND (ts.dur < 0 OR ts.ts + ts.dur > ${start_ts})
      AND ts.state = 'Running'
      AND ts.cpu IS NOT NULL
  )
  WHERE end_ts > ${start_ts}
  GROUP BY cpu, core_type
),
-- One row per tier present in _cpu_topology (prime/big/medium/little/unknown).
cpu_cluster_load_by_tier AS (
  SELECT
    cc.core_type,
    cc.core_count,
    COUNT(r.cpu) AS active_core_count,
    a.awake_ns,
    COALESCE(SUM(r.running_ns), 0) AS running_ns,
    COALESCE(MAX(r.running_ns), 0) AS max_core_running_ns
  FROM (
    SELECT core_type, COUNT(DISTINCT cpu_id) AS core_count
    FROM _cpu_topology
    GROUP BY core_type
  ) cc
  CROSS JOIN cpu_cluster_awake a
  LEFT JOIN cpu_cluster_core_running r ON r.core_type = cc.core_type
  GROUP BY cc.core_type, cc.core_count, a.awake_ns
)
SELECT
  CASE cs.core_type
    WHEN 'prime' THEN '超大核簇'
    WHEN 'big' THEN '大核簇'
    WHEN 'medium' THEN '中核簇'
    WHEN 'little' THEN '小核簇'
    ELSE '未分类核心'
  END AS cluster,
  cs.core_count,
  cs.active_core_count,
  ROUND(cs.awake_ns / 1e6, 2) AS awake_ms,
  ROUND(cs.running_ns / 1e6, 2) AS running_ms,
  ROUND(cs.awake_ns * cs.core_count / 1e6, 2) AS total_capacity_ms,
  ROUND(100.0 * cs.running_ns / NULLIF(cs.awake_ns * cs.core_count, 0), 1) AS load_pct,
  ROUND(100.0 - 100.0 * cs.running_ns / NULLIF(cs.awake_ns * cs.core_count, 0), 1) AS idle_pct,
  ROUND(100.0 * cs.max_core_running_ns / NULLIF(cs.awake_ns, 0), 1) AS max_single_core_pct
FROM cpu_cluster_load_by_tier cs
ORDER BY CASE cs.core_type
  WHEN 'prime' THEN 0 WHEN 'big' THEN 1 WHEN 'medium' THEN 2 WHEN 'little' THEN 3 ELSE 4
END

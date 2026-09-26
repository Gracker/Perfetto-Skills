-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: 2af64b097eb6ef55456b39938820e6bc4ae09d23ff1331109751e7499b6603f3
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- Global CPU spans retain peer identity. Consumers join system_target_threads
-- explicitly; no global process-table replacement or synthetic switch boundary.
-- Capacity extrema require a complete machine population. A missing capacity
-- on any CPU prevents certifying which recorded CPU is fastest or smallest.
system_cpu_topology AS (
  SELECT c.id AS ucpu,c.cpu,c.machine_id,c.cluster_id,c.capacity,
    CASE WHEN c.recorded_capacity_count<c.machine_cpu_count THEN 'unknown'
      WHEN c.min_capacity=c.max_capacity THEN 'unknown'
      WHEN c.capacity=c.min_capacity THEN 'little'
      WHEN c.capacity=c.max_capacity THEN 'big'
      ELSE 'medium' END AS core_type,
    CASE WHEN c.recorded_capacity_count=0 THEN 'capacity_unavailable'
      WHEN c.recorded_capacity_count<c.machine_cpu_count THEN 'capacity_incomplete'
      WHEN c.min_capacity=c.max_capacity THEN 'capacity_uniform_no_big_little'
      ELSE 'recorded_capacity' END AS topology_source
  FROM (
    SELECT cpu.*,
      COUNT(*) OVER (PARTITION BY machine_id) AS machine_cpu_count,
      COUNT(CASE WHEN capacity>0 THEN 1 END) OVER (PARTITION BY machine_id) AS recorded_capacity_count,
      MIN(CASE WHEN capacity>0 THEN capacity END) OVER (PARTITION BY machine_id) AS min_capacity,
      MAX(CASE WHEN capacity>0 THEN capacity END) OVER (PARTITION BY machine_id) AS max_capacity
    FROM cpu
  ) c
),
system_sched_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    s.id AS sched_id, s.utid, t.upid, t.is_idle, s.cpu, s.ucpu,
    s.ts AS raw_start_ts, s.dur AS raw_dur,
    CASE WHEN s.dur >= 0 THEN s.ts + s.dur END AS raw_end_ts,
    MAX(s.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, w.window_end_ts) AS clipped_end_ts,
    MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, w.window_end_ts) - MAX(s.ts, w.window_start_ts) AS dur_ns,
    s.dur = -1 AS is_unfinished,
    s.ts < w.window_start_ts AS left_censored,
    s.dur = -1 OR s.ts + s.dur > w.window_end_ts AS right_censored,
    s.end_state, s.priority,
    ct.machine_id, ct.cluster_id, ct.capacity,
    COALESCE(ct.core_type, 'unknown') AS core_type,
    COALESCE(ct.topology_source, 'cpu_identity_unavailable') AS topology_source
  FROM system_windows w JOIN sched_slice s
    ON s.ts < w.window_end_ts AND s.dur >= -1 AND s.dur != 0
      AND CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
        ELSE s.ts + s.dur END > w.window_start_ts
  LEFT JOIN thread t ON t.utid = s.utid
  LEFT JOIN system_cpu_topology ct ON ct.ucpu = s.ucpu
  WHERE w.window_end_ts > w.window_start_ts
)
,
system_windows AS (SELECT 0 AS window_id,
  COALESCE(${start_ts},(SELECT start_ts FROM trace_bounds)) AS window_start_ts,
  COALESCE(${end_ts},(SELECT end_ts FROM trace_bounds)) AS window_end_ts),
clipped_sched AS (SELECT s.*,s.clipped_start_ts AS ts,s.dur_ns AS dur FROM system_sched_spans s),
cpu_by_process AS (
  SELECT
    p.upid as upid,
    SUM(ss.dur) as cpu_dur
  FROM clipped_sched ss
  JOIN thread t ON ss.utid = t.utid
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${start_ts} IS NULL OR ss.ts + ss.dur > ${start_ts})
    AND (${end_ts} IS NULL OR ss.ts < ${end_ts})
  GROUP BY p.upid
),
candidates AS (
  SELECT
    p.upid,
    p.pid,
    p.name as process_name,
    COALESCE(cb.cpu_dur, 0) as cpu_dur
  FROM effective_target_processes p
  LEFT JOIN cpu_by_process cb USING (upid)
  WHERE (${__process_scope.upid} IS NOT NULL OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
    -- 避免 package 为空时选到内核线程 (kworker 等)
    AND p.name NOT GLOB 'kworker*'
    AND p.name NOT GLOB 'swapper*'
    AND p.name NOT GLOB 'rcu*'
    AND p.name NOT GLOB 'irq*'
    AND p.name NOT GLOB 'migration*'
    AND p.name NOT GLOB 'ksoftirqd*'
)
SELECT
  upid,
  pid,
  process_name
FROM candidates
ORDER BY
  CASE WHEN '${package}' != '' AND ('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') THEN 0 ELSE 1 END,
  -- package 为空时优先选择 app 进程（通常包含 '.'）
  CASE WHEN '${package}' = '' AND process_name LIKE '%.%' THEN 0 ELSE 1 END,
  cpu_dur DESC,
  pid DESC
LIMIT 1

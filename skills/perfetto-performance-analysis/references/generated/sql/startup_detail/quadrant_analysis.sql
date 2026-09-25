-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: 33481081237e74c06b4dc8d1d96123519db58062a3214483d83a5ab46c43d287
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Inputs: system_windows(window_id, window_start_ts, window_end_ts),
-- system_target_threads(window_id, upid, utid, role). Half-open intersections.
-- Unfinished states are observed only through the trace bound; clipping never
-- converts that bound into a real switch/wakeup event.
system_thread_state_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    tt.upid, tt.utid, tt.role, ts.id AS thread_state_id,
    ts.ts AS raw_start_ts, ts.dur AS raw_dur,
    CASE WHEN ts.dur >= 0 THEN ts.ts + ts.dur END AS raw_end_ts,
    MAX(ts.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END, w.window_end_ts) AS clipped_end_ts,
    MIN(CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END, w.window_end_ts) - MAX(ts.ts, w.window_start_ts) AS dur_ns,
    ts.dur = -1 AS is_unfinished,
    ts.ts < w.window_start_ts AS left_censored,
    ts.dur = -1 OR ts.ts + ts.dur > w.window_end_ts AS right_censored,
    ts.state, ts.cpu, ts.ucpu, ts.io_wait, ts.blocked_function, ts.waker_utid, ts.irq_context
  FROM system_windows w
  JOIN system_target_threads tt ON tt.window_id = w.window_id
  JOIN thread_state ts ON ts.utid = tt.utid
  WHERE w.window_end_ts > w.window_start_ts AND ts.dur != 0 AND ts.dur >= -1
    AND ts.ts < w.window_end_ts
    AND CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END > w.window_start_ts
)
,
system_windows AS (SELECT 0 AS window_id,
  COALESCE(${start_ts},(SELECT start_ts FROM trace_bounds)) AS window_start_ts,
  COALESCE(${end_ts},(SELECT end_ts FROM trace_bounds)) AS window_end_ts),
system_target_threads AS (
  SELECT w.window_id,p.upid,t.utid,CASE WHEN t.tid=p.pid THEN 'main' ELSE 'target' END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p JOIN thread t ON t.upid=p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*')
),
clipped_states AS (SELECT s.*,s.clipped_start_ts AS ts,s.dur_ns AS dur FROM system_thread_state_spans s),
main_thread AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid, p.name as process_name
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND t.tid = p.pid
),
clipped_statess AS (
  SELECT
    ts.utid,
    ts.state,
    ts.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    COALESCE(ct.topology_source, 'unavailable') as topology_source,
    SUM(
      MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts})
    ) / 1e6 as dur_ms
  FROM clipped_states ts
  JOIN main_thread mt ON ts.utid = mt.utid
  LEFT JOIN system_cpu_topology ct ON ts.ucpu = ct.ucpu
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
  GROUP BY ts.utid, ts.state, ts.cpu
),
quadrant_data AS (
  SELECT
    CASE
      WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') THEN 'Q1_big_running'
      WHEN state = 'Running' AND core_type IN ('little') THEN 'Q2_little_running'
      WHEN state IN ('R', 'R+') THEN 'Q3_runnable'
      WHEN state IN ('D', 'DK') THEN 'Q4a_uninterruptible'
      WHEN state IN ('S', 'I') THEN 'Q4b_sleeping'
      WHEN state = 'Running' THEN 'unknown_running'
      ELSE 'other'
    END as quadrant,
    topology_source,
    dur_ms
  FROM clipped_statess
)
SELECT
  'MainThread' as thread_type,
  ROUND(SUM(CASE WHEN quadrant = 'Q1_big_running' THEN dur_ms ELSE 0 END), 2) as q1_big_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q2_little_running' THEN dur_ms ELSE 0 END), 2) as q2_little_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ms ELSE 0 END), 2) as q3_runnable_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q4a_uninterruptible' THEN dur_ms ELSE 0 END), 2) as q4a_uninterruptible_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q4b_sleeping' THEN dur_ms ELSE 0 END), 2) as q4b_sleeping_ms,
  ROUND(SUM(dur_ms), 2) as total_ms,
  -- 百分比
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q1_big_running' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q1_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q2_little_running' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q2_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q3_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4a_uninterruptible' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q4a_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4b_sleeping' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q4b_pct,
  GROUP_CONCAT(DISTINCT topology_source) as classify_method,
  ROUND(SUM(CASE WHEN quadrant = 'unknown_running' THEN dur_ms ELSE 0 END), 2) as unknown_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'other' THEN dur_ms ELSE 0 END), 2) as other_state_ms
FROM quadrant_data
GROUP BY 1

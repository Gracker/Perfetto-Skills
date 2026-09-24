-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 69869c165513d6e975cde75d83230b412b1276132fd888e9d2fbf6a898cc2db3
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

WITH
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
system_windows AS (
  SELECT 0 AS window_id, COALESCE(${anr_ts}-${timeout_ns}, (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${anr_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
),system_target_threads AS (
  SELECT w.window_id,p.upid,t.utid,CASE WHEN t.tid = p.pid THEN 'MainThread' ELSE t.name END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p JOIN thread t ON t.upid=p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR (${upid}>0 AND p.upid=${upid}) OR (${upid}<=0 AND ${pid}>0 AND p.pid=${pid} AND ('${process_name}'='' OR p.name='${process_name}' OR p.name GLOB '${process_name}:*')) OR (${upid}<=0 AND ${pid}<=0 AND (p.name='${process_name}' OR p.name GLOB '${process_name}:*'))) AND (t.tid=p.pid)
),scene_states AS (
  SELECT s.*,COALESCE(ct.core_type,'unknown') AS core_type,
    COALESCE(ct.topology_source,'cpu_identity_unavailable') AS topology_source
  FROM system_thread_state_spans s LEFT JOIN system_cpu_topology ct ON ct.ucpu=s.ucpu
)
SELECT upid,utid,role AS thread_type,
  ROUND(SUM(CASE WHEN state='Running' AND core_type IN ('prime','big','medium') THEN dur_ns ELSE 0 END)/1e6,2) AS q1_big_running_ms,
  ROUND(SUM(CASE WHEN state='Running' AND core_type='little' THEN dur_ns ELSE 0 END)/1e6,2) AS q2_little_running_ms,
  ROUND(SUM(CASE WHEN state='Running' AND core_type='unknown' THEN dur_ns ELSE 0 END)/1e6,2) AS unknown_running_ms,
  ROUND(SUM(CASE WHEN state IN ('R','R+') THEN dur_ns ELSE 0 END)/1e6,2) AS q3_runnable_ms,
  ROUND(SUM(CASE WHEN state IN ('S','I','D','DK') THEN dur_ns ELSE 0 END)/1e6,2) AS q4_sleeping_ms,
  ROUND(SUM(CASE WHEN state IN ('D','DK') THEN dur_ns ELSE 0 END)/1e6,2) AS uninterruptible_ms,
  ROUND(SUM(CASE WHEN state IN ('S','I') THEN dur_ns ELSE 0 END)/1e6,2) AS interruptible_sleep_ms,
  ROUND(SUM(dur_ns)/1e6,2) AS total_ms,
  ROUND(100.0*SUM(CASE WHEN state='Running' THEN dur_ns ELSE 0 END)/NULLIF(SUM(dur_ns),0),1) AS running_pct,
  ROUND(100.0*SUM(CASE WHEN state IN ('R','R+') THEN dur_ns ELSE 0 END)/NULLIF(SUM(dur_ns),0),1) AS runnable_pct,
  ROUND(100.0*SUM(CASE WHEN state IN ('S','I','D','DK') THEN dur_ns ELSE 0 END)/NULLIF(SUM(dur_ns),0),1) AS sleeping_pct,
  ROUND(100.0*SUM(dur_ns)/NULLIF(MAX(window_end_ts-window_start_ts),0),1) AS state_coverage_pct,
  GROUP_CONCAT(DISTINCT topology_source) AS classify_method,
  CASE WHEN SUM(CASE WHEN state IN ('S','I','D','DK') THEN dur_ns ELSE 0 END)>0.8*SUM(dur_ns) THEN 'waiting_dominant'
    WHEN SUM(CASE WHEN state IN ('R','R+') THEN dur_ns ELSE 0 END)>0.3*SUM(dur_ns) THEN 'runnable_dominant'
    WHEN SUM(CASE WHEN state='Running' THEN dur_ns ELSE 0 END)>0.7*SUM(dur_ns) THEN 'busy_running' ELSE 'mixed' END AS status_verdict
FROM scene_states GROUP BY window_id,upid,utid,role

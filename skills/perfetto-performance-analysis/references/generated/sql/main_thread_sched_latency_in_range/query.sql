-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_sched_latency_in_range.skill.yaml
-- Source SHA-256: 63e24db148afece3081efeb7a7cf445aa6822776d4b377c8acb5537057d979e2
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

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
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*') AND t.tid=p.pid
)
SELECT s.upid,s.utid,t.tid,t.name AS thread_name,s.window_start_ts,s.window_end_ts,
  COUNT(*) AS runnable_count,SUM(s.dur_ns)/1e6 AS total_runnable_ms,
  MAX(s.dur_ns)/1e6 AS max_latency_ms,AVG(s.dur_ns)/1e6 AS avg_latency_ms,
  SUM(CASE WHEN s.dur_ns>2000000 THEN 1 ELSE 0 END) AS long_wait_count,
  SUM(CASE WHEN s.dur_ns>8000000 THEN 1 ELSE 0 END) AS severe_count,
  SUM(CASE WHEN s.state='R+' THEN s.dur_ns ELSE 0 END)/1e6 AS runnable_preempted_ms,
  SUM(CASE WHEN s.right_censored THEN 1 ELSE 0 END) AS right_censored_count,
  'window_clipped_runnable_intervals' AS latency_evidence
FROM system_thread_state_spans s JOIN thread t ON t.utid=s.utid
WHERE s.state IN ('R','R+')
GROUP BY s.window_id,s.utid ORDER BY total_runnable_ms DESC

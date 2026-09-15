-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/scheduling_analysis.skill.yaml
-- Source SHA-256: b31cc396cd518f4b46e71db1d3f0fde3f4eec0116380fc97e47ca43bf7c5bc93
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

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
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*')
)
SELECT tt.upid,t.utid,t.tid,t.name AS thread_name,p.name AS process_name,t.tid=p.pid AS is_main_thread,
  w.window_start_ts,w.window_end_ts,
  SUM(CASE WHEN s.state='Running' THEN s.dur_ns ELSE 0 END)/1e6 AS running_ms,
  SUM(CASE WHEN s.state IN ('R','R+') THEN s.dur_ns ELSE 0 END)/1e6 AS runnable_ms,
  SUM(CASE WHEN s.state='R+' THEN s.dur_ns ELSE 0 END)/1e6 AS runnable_preempted_ms,
  SUM(CASE WHEN s.state IN ('S','I') THEN s.dur_ns ELSE 0 END)/1e6 AS sleeping_ms,
  SUM(CASE WHEN s.state IN ('D','DK') THEN s.dur_ns ELSE 0 END)/1e6 AS uninterruptible_ms,
  SUM(CASE WHEN s.state NOT IN ('Running','R','R+','S','I','D','DK') THEN s.dur_ns ELSE 0 END)/1e6 AS other_state_ms,
  MAX(CASE WHEN s.state IN ('R','R+') THEN s.dur_ns ELSE 0 END)/1e6 AS max_runnable_ms,
  COUNT(CASE WHEN s.state IN ('R','R+') AND s.dur_ns>5000000 THEN 1 END) AS long_runnable_count,
  SUM(s.dur_ns) AS state_covered_ns,
  CASE WHEN COUNT(s.thread_state_id)=0 THEN 'unavailable'
    WHEN SUM(s.dur_ns)<w.window_end_ts-w.window_start_ts THEN 'partial' ELSE 'observed' END AS state_evidence
FROM system_target_threads tt JOIN system_windows w ON tt.window_id=w.window_id
JOIN thread t ON t.utid=tt.utid JOIN process p ON p.upid=tt.upid
LEFT JOIN system_thread_state_spans s ON s.window_id=tt.window_id AND s.utid=tt.utid
GROUP BY tt.window_id,tt.utid
ORDER BY runnable_ms DESC,uninterruptible_ms DESC,running_ms DESC

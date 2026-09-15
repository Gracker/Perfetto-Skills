-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: a4b934d0ea9e3be026e38cff778d34fc9482780ab04a5fd0a4d3f6542323e245
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
main_thread AS (
  SELECT t.utid, p.upid, p.name as process_name
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR p.name = '${target_process.data[0].process_name}')
    AND t.tid = p.pid
  LIMIT 1
),
slow_inputs AS (
  SELECT
    dispatch_ts as input_ts,
    receive_ts + receive_dur as input_end_ts,
    total_latency_dur,
    event_type
  FROM android_input_events
  WHERE process_name = '${target_process.data[0].process_name}'
    AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
    AND total_latency_dur > ${thread_state_min_dur_ms|50} * 1000000  -- > thread state threshold
  ORDER BY total_latency_dur DESC
  LIMIT 10
),
system_windows AS (
  SELECT ROW_NUMBER() OVER (ORDER BY input_ts,input_end_ts,event_type) AS window_id,
    MAX(input_ts,COALESCE(${start_ts},input_ts)) AS window_start_ts,
    MIN(input_end_ts,COALESCE(${end_ts},input_end_ts)) AS window_end_ts,event_type,total_latency_dur
  FROM slow_inputs
),
system_target_threads AS (
  SELECT w.window_id,t.upid,t.utid,'main' AS role FROM system_windows w CROSS JOIN main_thread t
)
SELECT s.window_id,s.upid,s.utid,w.event_type,w.total_latency_dur/1e6 AS input_dur_ms,
  s.state,SUM(s.dur_ns)/1e6 AS state_dur_ms,s.blocked_function,
  w.window_start_ts,w.window_end_ts
FROM system_thread_state_spans s JOIN system_windows w ON w.window_id=s.window_id
GROUP BY s.window_id,s.upid,s.utid,s.state,s.blocked_function
ORDER BY w.total_latency_dur DESC,state_dur_ms DESC
LIMIT 30

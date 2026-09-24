-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 69869c165513d6e975cde75d83230b412b1276132fd888e9d2fbf6a898cc2db3
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

WITH
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
main_thread AS (
  SELECT t.utid, t.upid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (
      ${__process_scope.upid} IS NOT NULL
      OR (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
),
system_windows AS (
  SELECT 0 AS window_id,${anr_ts}-${timeout_ns} AS window_start_ts,${anr_ts} AS window_end_ts
),
system_target_threads AS (
  SELECT w.window_id,t.upid,t.utid,'MainThread' AS role FROM system_windows w CROSS JOIN main_thread t
),
wakeup_events AS (
  SELECT e.utid,e.ts,COUNT(*) AS event_rows,
    CASE WHEN COUNT(*)=1 THEN MAX(e.waker_utid) END AS waker_utid,
    CASE WHEN COUNT(*)=1 THEN MAX(e.irq_context) END AS irq_context
  FROM thread_state e JOIN system_target_threads t ON t.utid=e.utid
  JOIN system_windows w ON w.window_id=t.window_id
  WHERE e.state IN ('R','R+') AND e.ts>=w.window_start_ts AND e.ts<w.window_end_ts
  GROUP BY e.utid,e.ts
)
SELECT s.upid,s.utid,
  COALESCE(waker_thread.name,'unknown') AS waker_thread,
  COALESCE(waker_process.name,'unknown') AS waker_process,
  s.blocked_function,
  COUNT(*) AS wait_span_count,
  SUM(CASE WHEN e.event_rows=1 AND (e.waker_utid IS NOT NULL OR e.irq_context=1) THEN 1 ELSE 0 END) AS wakeup_count,
  SUM(s.is_unfinished) AS unfinished_wait_count,
  SUM(s.left_censored) AS left_censored_wait_count,
  SUM(s.right_censored) AS right_censored_wait_count,
  ROUND(AVG(s.dur_ns)/1e6,2) AS avg_sleep_ms,
  ROUND(MAX(s.dur_ns)/1e6,2) AS max_sleep_ms,
  ROUND(SUM(s.dur_ns)/1e6,2) AS total_sleep_ms,
  ROUND(MAX(CASE WHEN s.raw_dur>=0 THEN s.raw_dur END)/1e6,2) AS raw_max_sleep_ms,
  'overlap_waits_with_in_window_wakeup_events' AS evidence_scope
FROM system_thread_state_spans s
LEFT JOIN wakeup_events e ON e.utid=s.utid AND e.ts=s.raw_end_ts
LEFT JOIN thread waker_thread ON e.waker_utid=waker_thread.utid
LEFT JOIN process waker_process ON waker_thread.upid=waker_process.upid
WHERE s.state IN ('S','I','D','DK') AND s.dur_ns>=1000000
GROUP BY s.upid,s.utid,waker_thread.name,waker_process.name,s.blocked_function
ORDER BY total_sleep_ms DESC LIMIT 10

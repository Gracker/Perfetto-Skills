-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_thread_blocking_graph.skill.yaml
-- Source SHA-256: 69238dda35542463041b9a6abaac5497e3ce646dd30ab5172692caa825eb5d2f
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
process_threads AS (
  SELECT t.utid,t.upid,t.name AS thread_name,
    CASE WHEN t.tid=p.pid THEN 'main'
      WHEN t.name='RenderThread' THEN 'render'
      WHEN t.name GLOB '*HeapTaskDaemon*' OR t.name GLOB '*FinalizerDaemon*' THEN 'gc'
      WHEN t.name GLOB 'Jit thread pool*' THEN 'jit'
      WHEN t.name GLOB 'Binder:*' THEN 'binder' ELSE 'other' END AS role
  FROM thread t JOIN process p ON t.upid=p.upid
  WHERE ('${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*')
),
system_windows AS (
  SELECT 0 AS window_id,${start_ts} AS window_start_ts,${end_ts} AS window_end_ts
),
system_target_threads AS (
  SELECT w.window_id,t.upid,t.utid,t.role FROM system_windows w CROSS JOIN process_threads t
),
wakeup_events AS (
  SELECT e.utid,e.ts,COUNT(*) AS event_rows,
    CASE WHEN COUNT(*)=1 THEN MAX(e.id) END AS wakeup_state_id,
    CASE WHEN COUNT(*)=1 THEN MAX(e.waker_utid) END AS observed_waker_utid,
    CASE WHEN COUNT(*)=1 THEN MAX(e.irq_context) END AS irq_context
  FROM thread_state e JOIN process_threads t ON t.utid=e.utid
  CROSS JOIN system_windows w
  WHERE e.state IN ('R','R+') AND e.ts>=w.window_start_ts AND e.ts<w.window_end_ts
  GROUP BY e.utid,e.ts
),
waits AS (
  SELECT wait_span.*,t.thread_name,e.event_rows,e.wakeup_state_id,e.observed_waker_utid,e.irq_context AS wake_irq_context,
    CASE WHEN e.event_rows=1 THEN e.ts END AS wakeup_ts,
    CASE WHEN e.event_rows=1 AND COALESCE(e.irq_context,0)!=1 THEN e.observed_waker_utid END AS resolved_waker_utid,
    CASE WHEN e.event_rows>1 THEN 'ambiguous_successor'
      WHEN e.irq_context=1 THEN 'observed_irq'
      WHEN e.observed_waker_utid IS NOT NULL THEN 'observed_thread'
      WHEN e.event_rows=1 THEN 'successor_without_wake_metadata'
      ELSE 'no_in_window_wakeup' END AS wakeup_status
  FROM system_thread_state_spans wait_span JOIN process_threads t ON t.utid=wait_span.utid
  LEFT JOIN wakeup_events e ON e.utid=wait_span.utid AND e.ts=wait_span.raw_end_ts
  WHERE wait_span.state IN ('S','I','D','DK') AND wait_span.dur_ns>${min_block_ms|1}*1000000
),
-- Only a unique deepest slice is a usable contemporaneous task observation.
active_waker_slices AS (
  SELECT w.thread_state_id,s.id,s.name,s.depth
  -- Resolve the wait's waker before scanning its track; reordering across
  -- wakeup_events' LEFT JOIN can otherwise scan slices before waker filtering.
  FROM waits w CROSS JOIN thread_track tt ON tt.utid=w.resolved_waker_utid
  CROSS JOIN slice s ON s.track_id=tt.id
  WHERE s.ts<=w.wakeup_ts AND s.dur>=-1 AND s.dur!=0
    AND CASE WHEN s.dur=-1 THEN (SELECT end_ts FROM trace_bounds) ELSE s.ts+s.dur END>w.wakeup_ts
),
deepest_waker_slices AS (
  SELECT a.thread_state_id,COUNT(*) AS candidate_count,
    CASE WHEN COUNT(*)=1 THEN MAX(a.id) END AS waker_slice_id,
    CASE WHEN COUNT(*)=1 THEN MAX(a.name) END AS waker_current_slice
  FROM active_waker_slices a
  WHERE a.depth=(SELECT MAX(b.depth) FROM active_waker_slices b WHERE b.thread_state_id=a.thread_state_id)
  GROUP BY a.thread_state_id
)
SELECT w.upid,w.utid,w.thread_state_id,w.thread_name AS blocked_thread,w.role AS blocked_role,
  w.state AS blocked_state,NULLIF(w.blocked_function,'') AS blocked_function,
  printf('%d',w.raw_start_ts) AS raw_start_ts,
  CASE WHEN w.raw_end_ts IS NOT NULL THEN printf('%d',w.raw_end_ts) END AS raw_end_ts,
  printf('%d',w.clipped_start_ts) AS start_ts,printf('%d',w.clipped_end_ts) AS end_ts,
  w.is_unfinished,w.left_censored,w.right_censored,
  w.wakeup_state_id,CASE WHEN w.wakeup_ts IS NOT NULL THEN printf('%d',w.wakeup_ts) END AS wakeup_ts,
  w.observed_waker_utid,w.wake_irq_context AS irq_context,w.resolved_waker_utid AS waker_utid,wt.upid AS waker_upid,
  COALESCE(wt.name,'unknown') AS waker_thread,COALESCE(wp.name,'unknown') AS waker_process,
  COALESCE(ds.waker_current_slice,'-') AS waker_current_slice,ds.waker_slice_id,
  CASE WHEN ds.candidate_count=1 THEN 'observed_unique_deepest'
    WHEN ds.candidate_count>1 THEN 'ambiguous_deepest' ELSE 'not_observed' END AS waker_slice_status,
  w.wakeup_status,
  CASE WHEN w.wakeup_status IN ('observed_irq','observed_thread') THEN 1 ELSE 0 END AS wakeup_count,
  1 AS block_count,ROUND(w.dur_ns/1e6,2) AS total_block_ms,
  ROUND(w.dur_ns/1e6,2) AS max_block_ms,ROUND(w.dur_ns/1e6,2) AS avg_block_ms,
  'observed_wakeup_not_proven_blocking_cause' AS relation_status,
  'one_wait_span_clipped_to_window' AS evidence_scope
FROM waits w LEFT JOIN thread wt ON wt.utid=w.resolved_waker_utid
LEFT JOIN process wp ON wp.upid=wt.upid
LEFT JOIN deepest_waker_slices ds ON ds.thread_state_id=w.thread_state_id
ORDER BY CASE w.role WHEN 'main' THEN 0 WHEN 'render' THEN 1 ELSE 2 END,w.dur_ns DESC,w.thread_state_id
LIMIT ${top_k|20}

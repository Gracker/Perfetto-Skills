-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 88ec9683e76751ade4cdc4a899a482dfba921d757006beab05b108b52ba9d299
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

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
system_windows AS (
  SELECT 0 AS window_id,
    COALESCE(${start_ts},${anr_ts}-5000000000,(SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts},${anr_ts}+1000000000,(SELECT end_ts FROM trace_bounds)) AS window_end_ts
),
main_thread AS (
  SELECT t.utid,t.upid,p.name AS process_name FROM thread t JOIN process p ON t.upid=p.upid
  WHERE t.tid=p.pid AND (
    ('${process_name}' != '' AND (p.name='${process_name}' OR p.name GLOB '${process_name}:*'))
    OR ('${process_name}' = '' AND p.uid % 100000 >= 10000)
  )
),
system_target_threads AS (
  SELECT w.window_id,t.upid,t.utid,'main' AS role FROM system_windows w CROSS JOIN main_thread t
),
wakeup_events AS (
  SELECT e.utid,e.ts,COUNT(*) AS event_rows,
    CASE WHEN COUNT(*)=1 THEN MAX(e.id) END AS wakeup_state_id,
    CASE WHEN COUNT(*)=1 THEN MAX(e.waker_utid) END AS observed_waker_utid,
    CASE WHEN COUNT(*)=1 THEN MAX(e.irq_context) END AS irq_context
  FROM thread_state e JOIN main_thread t ON t.utid=e.utid CROSS JOIN system_windows w
  WHERE e.state IN ('R','R+') AND e.ts>=w.window_start_ts AND e.ts<w.window_end_ts
  GROUP BY e.utid,e.ts
),
waits AS (
  SELECT s.*,e.event_rows,e.wakeup_state_id,e.observed_waker_utid,e.irq_context AS wake_irq_context,
    CASE WHEN e.event_rows=1 THEN e.ts END AS wakeup_ts,
    CASE WHEN e.event_rows=1 AND COALESCE(e.irq_context,0)!=1 THEN e.observed_waker_utid END AS resolved_waker_utid,
    CASE WHEN e.event_rows>1 THEN 'ambiguous_successor'
      WHEN e.irq_context=1 THEN 'observed_irq'
      WHEN e.observed_waker_utid IS NOT NULL THEN 'observed_thread'
      WHEN e.event_rows=1 THEN 'successor_without_wake_metadata'
      ELSE 'no_in_window_wakeup' END AS wakeup_status
  FROM system_thread_state_spans s
  LEFT JOIN wakeup_events e ON e.utid=s.utid AND e.ts=s.raw_end_ts
  WHERE s.state IN ('S','I','D','DK') AND s.dur_ns>0
),
ranked_waits AS (
  SELECT w.*,ROW_NUMBER() OVER(PARTITION BY w.upid,w.is_unfinished ORDER BY w.dur_ns DESC,w.thread_state_id) AS process_wait_rank
  FROM waits w
  WHERE '${process_name}' != '' OR (
    w.state IN ('S','D','DK') AND w.dur_ns >= MAX(0,${min_wait_ms|3000})*1000000
  )
)
SELECT mt.process_name,'observed_wait_not_proven_unresponsiveness' AS candidate_status,
  w.upid,w.utid,w.thread_state_id,w.state AS blocked_state,w.blocked_function,
  printf('%d',w.raw_start_ts) AS raw_start_ts,
  CASE WHEN w.raw_end_ts IS NOT NULL THEN printf('%d',w.raw_end_ts) END AS raw_end_ts,
  printf('%d',w.clipped_start_ts) AS start_ts,printf('%d',w.clipped_end_ts) AS end_ts,
  w.is_unfinished,w.left_censored,w.right_censored,
  w.wakeup_state_id,CASE WHEN w.wakeup_ts IS NOT NULL THEN printf('%d',w.wakeup_ts) END AS ts,
  w.observed_waker_utid,w.wake_irq_context AS irq_context,w.resolved_waker_utid AS waker_utid,wt.upid AS waker_upid,
  COALESCE(wt.name,'unknown') AS waker_thread_name,COALESCE(wp.name,'unknown') AS waker_process_name,
  ROUND(w.dur_ns/1e6,2) AS sleep_dur_ms,
  CASE WHEN w.wakeup_status IN ('observed_irq','observed_thread') THEN 1 ELSE 0 END AS wakeup_count,
  1 AS wait_span_count,w.wakeup_status,
  'observed_wakeup_not_proven_blocking_cause' AS relation_status,
  'one_wait_span_clipped_to_window' AS evidence_scope
FROM ranked_waits w JOIN main_thread mt ON mt.utid=w.utid
LEFT JOIN thread wt ON wt.utid=w.resolved_waker_utid
LEFT JOIN process wp ON wp.upid=wt.upid
WHERE '${process_name}' != '' OR w.process_wait_rank=1
ORDER BY w.dur_ns DESC,w.thread_state_id
LIMIT CASE WHEN '${process_name}' != '' THEN 20 ELSE MIN(100,MAX(1,CAST(${top_n|20} AS INT))) END
OFFSET CASE WHEN '${process_name}' != '' THEN 0 ELSE MAX(0,CAST(${offset|0} AS INT)) END

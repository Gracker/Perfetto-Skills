-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: 989cec6fb1956e104659dcc758e1ca76a37d1a8b98930d2c6653997e4317cb30
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
  WHERE p.upid=${target_process.data[0].upid} AND (${__process_scope.upid} IS NOT NULL OR '${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*')
),
clipped_states AS (SELECT s.*,s.clipped_start_ts AS ts,s.dur_ns AS dur FROM system_thread_state_spans s),
main_thread AS (
  SELECT t.utid, t.name
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE p.upid = ${target_process.data[0].upid} AND t.tid = p.pid
  LIMIT 1
)
SELECT
  ${target_process.data[0].upid} AS upid,
  (SELECT window_start_ts FROM system_windows) AS window_start_ts, (SELECT window_end_ts FROM system_windows) AS window_end_ts,
  (SELECT utid FROM main_thread) AS utid,
  ts.dur / 1e6 as wait_ms,
  ts.ts / 1e6 as ts_ms,
  printf('%d', ts.ts) as ts_str,
  ts.dur as dur_ns,
  (SELECT name FROM main_thread) as thread_name,
  -- 关联唤醒者信息
  waker_t.name as waker_thread,
  waker_p.name as waker_process,
  CASE
    WHEN ts.dur / 1e6 > ${sched_delay_critical_ms|16} THEN 'critical'
    WHEN ts.dur / 1e6 > ${sched_delay_critical_ms|16} / 2 THEN 'warning'
    ELSE 'normal'
  END as severity
FROM clipped_states ts
LEFT JOIN thread waker_t ON ts.waker_utid = waker_t.utid
LEFT JOIN process waker_p ON waker_t.upid = waker_p.upid
WHERE ts.utid = (SELECT utid FROM main_thread)
  AND ts.state IN ('R', 'R+')
  AND ts.dur > 1000000  -- > 1ms
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
ORDER BY ts.dur DESC
LIMIT 20

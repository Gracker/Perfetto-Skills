-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 337f07b019184e56d2cbd55423b8bdf1d62ee20eb90821ab2d0791340050512f
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
system_windows AS (
  SELECT 0 AS window_id, COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
),
target_threads AS (
  SELECT t.utid, t.upid, t.tid, t.name as thread_name, p.pid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.tid = p.pid OR t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster' OR t.name GLOB '[0-9]*.ui')
),
system_target_threads AS (
  SELECT w.window_id,t.upid,t.utid,t.thread_name AS role FROM system_windows w CROSS JOIN target_threads t
),
io_states AS (
  SELECT
    tt.thread_name,
    ts.upid, ts.utid, ts.dur_ns AS dur, ts.raw_dur, ts.is_unfinished, ts.left_censored, ts.right_censored,
    ts.state,
    ts.io_wait,
    ts.blocked_function
  FROM system_thread_state_spans ts
  JOIN target_threads tt ON ts.utid = tt.utid
  WHERE ts.state IN ('D', 'DK')
    AND (
      COALESCE(ts.io_wait, 0) = 1
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%folio_wait%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%sync%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%f2fs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%erofs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ufshcd%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%mmc_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%dm_%'
    )
    AND ts.dur_ns > 100000
)
SELECT
  upid, utid, thread_name,
  SUM(is_unfinished) AS unfinished_wait_count,
  SUM(left_censored) AS left_censored_wait_count,
  SUM(right_censored) AS right_censored_wait_count,
  ROUND(MAX(CASE WHEN raw_dur>=0 THEN raw_dur END)/1e6,2) AS raw_max_wait_ms,
  COUNT(*) as blocked_count,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_ms,
  MAX(io_wait) as io_wait,
  CASE
    WHEN MAX(io_wait) = 1 THEN 'direct_io_wait'
    ELSE 'inferred_io_or_page_cache'
  END as evidence_strength,
  COALESCE(
    MAX(blocked_function),
    CASE WHEN MAX(io_wait) = 1 THEN 'IO wait' ELSE 'kernel wait' END
  ) as io_cause
FROM io_states
GROUP BY upid, utid, thread_name
HAVING total_ms > 0.1
ORDER BY total_ms DESC

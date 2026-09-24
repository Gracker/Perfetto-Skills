-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: 2af64b097eb6ef55456b39938820e6bc4ae09d23ff1331109751e7499b6603f3
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- No input CTE. The kernel wait-channel (thread_state.blocked_function) families
-- that name file, page-cache or block I/O. Consumers test a lower-cased
-- blocked_function against every pattern:
--   EXISTS (SELECT 1 FROM io_blocked_function_families f
--           WHERE LOWER(COALESCE(ts.blocked_function, '')) GLOB f.pattern)
--
-- GLOB, not LIKE: in LIKE `_` is a one-character wildcard, so '%dm_%' also
-- matched 'dma_fence_wait_timeout' and booked GPU fence waits (D state, common
-- on RenderThread and SurfaceFlinger) as I/O; '%blk_%' and '%mmc_%' were
-- looser than written for the same reason. GLOB reads `_` literally and is
-- case-sensitive, hence the LOWER() on the consumer side.
--
-- blocked_function is a single-frame wchan, emitted by sched_blocked_reason for
-- D-state waits only. A match is an I/O candidate that still needs file,
-- page-fault or block-layer evidence; it is not proof of an I/O root cause.
io_blocked_function_families(pattern) AS (
  VALUES
    ('*io_schedule*'),
    ('*wait_on_page*'),
    ('*folio_wait*'),
    ('*wait_on_buffer*'),
    ('*submit_bio*'),
    ('*filemap*'),
    ('*page_fault*'),
    ('*ext4*'),
    ('*f2fs*'),
    ('*erofs*'),
    ('*blk_*'),
    ('*dm_*'),
    ('*mmc_*'),
    ('*ufshcd*')
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
  SELECT t.utid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE p.upid = ${target_process.data[0].upid} AND t.tid = p.pid
  LIMIT 1
)
SELECT
  ${target_process.data[0].upid} AS upid,
  (SELECT window_start_ts FROM system_windows) AS window_start_ts, (SELECT window_end_ts FROM system_windows) AS window_end_ts,
  (SELECT utid FROM main_thread) AS utid,
  ts.blocked_function,
  ts.state,
  ts.io_wait,
  CASE
    WHEN ts.state IN ('D', 'DK') AND COALESCE(ts.io_wait, 0) = 1 THEN 'direct_io_wait'
    WHEN ts.state IN ('D', 'DK') AND (
      EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE LOWER(COALESCE(ts.blocked_function, '')) GLOB f.pattern)
    ) THEN 'inferred_io_or_page_cache'
    WHEN ts.state IN ('D', 'DK') THEN 'ambiguous_uninterruptible_wait'
    WHEN ts.state = 'S' AND (LOWER(COALESCE(ts.blocked_function, '')) LIKE '%epoll%' OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%poll%') THEN 'poll_idle_or_ambiguous'
    WHEN ts.state = 'S' AND (LOWER(COALESCE(ts.blocked_function, '')) LIKE '%futex%' OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%mutex%' OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%monitor%') THEN 'lock_wait'
    WHEN LOWER(COALESCE(ts.blocked_function, '')) LIKE '%binder%' THEN 'binder_wait'
    ELSE 'state_only'
  END as evidence_strength,
  COUNT(*) as count,
  SUM(ts.dur) / 1e6 as total_dur_ms,
  ROUND(AVG(ts.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(ts.dur) / 1e6, 2) as max_dur_ms
FROM clipped_states ts
WHERE ts.utid = (SELECT utid FROM main_thread)
  AND ts.blocked_function IS NOT NULL
  AND ts.dur > 1000000  -- > 1ms
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
GROUP BY ts.blocked_function, ts.state, ts.io_wait
ORDER BY total_dur_ms DESC
LIMIT 15

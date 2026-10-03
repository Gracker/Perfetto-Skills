-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 7ff32bd00930745e7472e3fd492581136074cf0cf6843caf8fecf18d85f1a757

WITH
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
  SELECT
    0 AS window_id,
    ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns} AS window_start_ts,
    ${anr_ctx.data[0].anr_ts} AS window_end_ts
),
system_target_threads AS (
  SELECT 0 AS window_id, t.upid, t.utid,
    CASE WHEN t.tid = p.pid THEN 'MainThread' ELSE 'Other' END AS role
  FROM thread t
  JOIN process p ON p.upid = t.upid
  WHERE t.upid = ${anr_ctx.data[0].upid}
),
d_waits AS (
  SELECT
    utid,
    role,
    LOWER(COALESCE(blocked_function, '')) AS wchan,
    blocked_function IS NOT NULL AS has_wchan,
    dur_ns AS ns
  FROM system_thread_state_spans
  WHERE state IN ('D', 'DK')
),
top_thread AS (
  SELECT utid, SUM(ns) AS ns
  FROM d_waits
  GROUP BY utid
  ORDER BY ns DESC
  LIMIT 1
)
SELECT
  (SELECT name FROM process WHERE upid = ${anr_ctx.data[0].upid}) AS process_name,
  ROUND(COALESCE(SUM(CASE WHEN role = 'MainThread' THEN ns END), 0) / 1e6, 2) AS main_thread_uninterruptible_ms,
  ROUND(COALESCE(SUM(ns), 0) / 1e6, 2) AS process_uninterruptible_ms,
  (SELECT t.name FROM top_thread tt JOIN thread t USING (utid)) AS top_thread_name,
  ROUND(COALESCE((SELECT ns FROM top_thread), 0) / 1e6, 2) AS top_thread_ms,
  ROUND(COALESCE(SUM(CASE WHEN role = 'MainThread'
    AND EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE wchan GLOB f.pattern) THEN ns END), 0) / 1e6, 2)
    AS main_thread_io_wchan_ms,
  ROUND(COALESCE(SUM(CASE WHEN wchan GLOB '*refrigerator*' THEN ns END), 0) / 1e6, 2) AS frozen_ms,
  ROUND(100.0 * SUM(CASE WHEN has_wchan THEN ns ELSE 0 END) / NULLIF(SUM(ns), 0), 1) AS blocked_function_coverage_pct
FROM d_waits

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_hot_slice_states.skill.yaml
-- Source SHA-256: 6f1cb08c42ead7e7aa287894f77a423902cbe8e0cbe67bea6e8b9699f7fc777c
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

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
sample_config AS (
  SELECT MAX(CAST(${top_n|10} AS INTEGER), 0) AS sample_limit
),
target_main_threads AS (
  SELECT
    p.upid, p.pid, p.name AS process_name,
    t.utid, t.tid, t.name AS thread_name
  FROM effective_target_processes p
  JOIN thread t ON t.upid = p.upid AND t.tid = p.pid
  WHERE ${__process_scope.upid} IS NOT NULL
    OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*'
),
eligible_slices AS (
  SELECT
    s.id AS slice_id, mt.upid, mt.utid, mt.pid, mt.tid,
    mt.process_name, mt.thread_name, s.name AS slice_name,
    s.ts AS raw_slice_ts, s.dur AS raw_slice_dur,
    CASE WHEN s.dur = -1 THEN NULL ELSE s.ts + s.dur END AS raw_slice_end_ts,
    MAX(s.ts, ${start_ts}) AS slice_ts,
    MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, ${end_ts}) AS slice_end_ts
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN target_main_threads mt ON mt.utid = tt.utid
  WHERE ${end_ts} > ${start_ts}
    AND s.dur != 0 AND s.dur >= -1
    AND s.ts < ${end_ts}
    AND CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END > ${start_ts}
    AND MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, ${end_ts}) - MAX(s.ts, ${start_ts}) >= 5000000
),
ranked_slices AS (
  SELECT es.*,
    es.slice_end_ts - es.slice_ts AS slice_dur_ns,
    ROW_NUMBER() OVER (
      ORDER BY es.slice_end_ts - es.slice_ts DESC, es.slice_ts ASC, es.slice_id ASC
    ) AS sample_rank,
    COUNT(*) OVER () AS eligible_slice_count
  FROM eligible_slices es
  WHERE es.slice_end_ts > es.slice_ts
),
hot_slices AS (
  SELECT rs.*, sc.sample_limit,
    MIN(rs.eligible_slice_count, sc.sample_limit) AS selected_slice_count
  FROM ranked_slices rs CROSS JOIN sample_config sc
  WHERE rs.sample_rank <= sc.sample_limit
),
state_overlaps AS (
  SELECT hs.slice_id, hs.utid, ts.state,
    ts.io_wait,
    NULLIF(ts.blocked_function, '') AS blocked_function,
    MIN(CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END, hs.slice_end_ts) - MAX(ts.ts, hs.slice_ts) AS state_dur_ns
  FROM hot_slices hs
  JOIN thread_state ts ON ts.utid = hs.utid
    AND ts.dur != 0 AND ts.dur >= -1
    AND ts.ts < hs.slice_end_ts
    AND CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END > hs.slice_ts
),
grouped_states AS (
  SELECT slice_id, utid, state, io_wait, blocked_function,
    SUM(state_dur_ns) AS state_dur_ns
  FROM state_overlaps
  WHERE state_dur_ns > 0
  GROUP BY slice_id, utid, state, io_wait, blocked_function
),
state_coverage AS (
  SELECT slice_id, utid, SUM(state_dur_ns) AS state_coverage_ns
  FROM grouped_states
  GROUP BY slice_id, utid
)
SELECT
  hs.sample_rank, hs.slice_id, hs.upid, hs.utid, hs.pid, hs.tid,
  hs.process_name, hs.thread_name,
  hs.slice_name,
  ROUND(hs.slice_dur_ns / 1e6, 2) as slice_dur_ms,
  printf('%d', hs.slice_ts) as slice_ts,
  printf('%d', hs.slice_end_ts) as slice_end_ts,
  printf('%d', hs.raw_slice_ts) as raw_slice_ts,
  CASE WHEN hs.raw_slice_end_ts IS NULL THEN NULL ELSE printf('%d', hs.raw_slice_end_ts) END as raw_slice_end_ts,
  CASE WHEN hs.raw_slice_dur = -1 THEN NULL ELSE ROUND(hs.raw_slice_dur / 1e6, 2) END as raw_slice_dur_ms,
  hs.raw_slice_ts < hs.slice_ts AS left_censored,
  hs.raw_slice_dur = -1 OR hs.raw_slice_end_ts > hs.slice_end_ts AS right_censored,
  hs.raw_slice_dur = -1 AS is_unfinished,
  COALESCE(gs.state, 'NotObserved') AS state,
  gs.io_wait,
  ROUND(COALESCE(gs.state_dur_ns, 0) / 1e6, 2) as state_dur_ms,
  ROUND(100.0 * COALESCE(gs.state_dur_ns, 0) / NULLIF(hs.slice_dur_ns, 0), 1) as state_pct,
  ROUND(COALESCE(sc.state_coverage_ns, 0) / 1e6, 2) AS state_coverage_ms,
  ROUND(100.0 * COALESCE(sc.state_coverage_ns, 0) / NULLIF(hs.slice_dur_ns, 0), 1) AS state_coverage_pct,
  ROUND(MAX(hs.slice_dur_ns - COALESCE(sc.state_coverage_ns, 0), 0) / 1e6, 2) AS uncovered_ms,
  CASE
    WHEN gs.state IS NULL THEN 'state_coverage_missing'
    WHEN gs.state IN ('D', 'DK') AND gs.io_wait = 1 THEN 'direct_io_wait'
    WHEN gs.state IN ('D', 'DK') AND (
      LOWER(gs.blocked_function) LIKE '%filemap%'
      OR LOWER(gs.blocked_function) LIKE '%page_fault%'
      OR LOWER(gs.blocked_function) LIKE '%wait_on_page%'
      OR LOWER(gs.blocked_function) LIKE '%folio_wait%'
      OR LOWER(gs.blocked_function) LIKE '%io_schedule%'
      OR LOWER(gs.blocked_function) LIKE '%submit_bio%'
      OR LOWER(gs.blocked_function) LIKE '%blk_%'
      OR LOWER(gs.blocked_function) LIKE '%ext4%'
      OR LOWER(gs.blocked_function) LIKE '%f2fs%'
      OR LOWER(gs.blocked_function) LIKE '%erofs%'
      OR LOWER(gs.blocked_function) LIKE '%ufshcd%'
      OR LOWER(gs.blocked_function) LIKE '%mmc_%'
      OR LOWER(gs.blocked_function) LIKE '%dm_%'
    ) THEN 'inferred_io_or_page_cache'
    WHEN gs.state IN ('D', 'DK') THEN 'ambiguous_uninterruptible_wait'
    WHEN gs.state = 'S' AND (LOWER(gs.blocked_function) LIKE '%epoll%' OR LOWER(gs.blocked_function) LIKE '%poll%') THEN 'poll_idle_or_ambiguous'
    WHEN gs.state = 'S' AND (LOWER(gs.blocked_function) LIKE '%futex%' OR LOWER(gs.blocked_function) LIKE '%mutex%' OR LOWER(gs.blocked_function) LIKE '%monitor%') THEN 'lock_wait'
    WHEN LOWER(gs.blocked_function) LIKE '%binder%' THEN 'binder_wait'
    ELSE 'state_only'
  END as evidence_strength,
  gs.blocked_function as blocked_functions,
  hs.sample_limit,
  'top_by_clipped_duration_within_analysis_window' AS sampling_scope,
  hs.eligible_slice_count, hs.selected_slice_count
FROM hot_slices hs
LEFT JOIN grouped_states gs ON gs.slice_id = hs.slice_id AND gs.utid = hs.utid
LEFT JOIN state_coverage sc ON sc.slice_id = hs.slice_id AND sc.utid = hs.utid
ORDER BY hs.sample_rank, state_dur_ms DESC, gs.state, gs.blocked_function

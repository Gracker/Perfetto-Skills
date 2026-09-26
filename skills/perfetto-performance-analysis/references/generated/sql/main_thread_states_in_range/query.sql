-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_states_in_range.skill.yaml
-- Source SHA-256: 7bad768d4547674b19d7268f5385de1b17e3746f458a9f2eaee723f02edde5c4
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (COALESCE(${__process_scope.upid}, ${upid|0}) > 0 AND p.upid = COALESCE(${__process_scope.upid}, ${upid|0}))
      OR (COALESCE(${__process_scope.upid}, ${upid|0}) <= 0 AND ${pid|0} > 0 AND p.pid = ${pid|0}
          AND ('${package|}' = '' OR p.name = '${package|}' OR p.name GLOB '${package|}:*'))
      OR (COALESCE(${__process_scope.upid}, ${upid|0}) <= 0 AND ${pid|0} <= 0
          AND ('${package|}' = '' OR p.name = '${package|}' OR p.name GLOB '${package|}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
)
SELECT
  ts.state,
  CASE ts.state
    WHEN 'Running' THEN 'Running (CPU执行)'
    WHEN 'R' THEN 'Runnable (等待调度)'
    WHEN 'R+' THEN 'Runnable+ (抢占等待)'
    WHEN 'S' THEN 'Sleeping (主动睡眠)'
    WHEN 'D' THEN 'Uninterruptible sleep (不可中断等待)'
    WHEN 'I' THEN 'Idle (空闲)'
    ELSE ts.state
  END as state_desc,
  NULLIF(ts.blocked_function, '') as blocked_function,
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
  ROUND(SUM(
    MIN(CASE WHEN ts.dur < 0 THEN ${end_ts} ELSE ts.ts + ts.dur END, ${end_ts}) - MAX(ts.ts, ${start_ts})
  ) / 1e6, 2) as total_dur_ms,
  ROUND(100.0 * SUM(
    MIN(CASE WHEN ts.dur < 0 THEN ${end_ts} ELSE ts.ts + ts.dur END, ${end_ts}) - MAX(ts.ts, ${start_ts})
  ) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as pct,
  COUNT(*) as count
FROM thread_state ts
JOIN main_thread mt ON ts.utid = mt.utid
WHERE ts.ts < ${end_ts}
  AND (CASE WHEN ts.dur < 0 THEN ${end_ts} ELSE ts.ts + ts.dur END) > ${start_ts}
GROUP BY ts.state, ts.io_wait, NULLIF(ts.blocked_function, '')
ORDER BY total_dur_ms DESC
LIMIT ${top_k|10}

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_states_in_range.skill.yaml
-- Source SHA-256: 47e6b6e9b545b31fe26b0e29c8e3ab63e959a93d20dcd35c28f09facb3963b61
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

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
state_rows AS (
  SELECT
    s.startup_id,
    s.dur AS startup_dur,
    ts.state,
    ts.io_wait,
    NULLIF(ts.blocked_function, '') AS blocked_function,
    LOWER(COALESCE(ts.blocked_function, '')) AS blocked_function_lc,
    MIN(CASE WHEN ts.dur < 0 THEN s.ts + s.dur ELSE ts.ts + ts.dur END, s.ts + s.dur) - MAX(ts.ts, s.ts) AS clipped_dur
  FROM thread_state ts
  JOIN android_startup_threads st ON ts.utid = st.utid
  JOIN android_startups s ON st.startup_id = s.startup_id
  WHERE st.is_main_thread = 1
    AND (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
    AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
    AND ts.ts < s.ts + s.dur
    AND (CASE WHEN ts.dur < 0 THEN s.ts + s.dur ELSE ts.ts + ts.dur END) > s.ts
)
SELECT
  state,
  CASE state
    WHEN 'Running' THEN 'Running (CPU执行)'
    WHEN 'R' THEN 'Runnable (等待调度)'
    WHEN 'R+' THEN 'Runnable+ (抢占等待)'
    WHEN 'S' THEN 'Sleeping (可中断睡眠/等待)'
    WHEN 'D' THEN CASE WHEN io_wait = 1 THEN 'Uninterruptible sleep (io_wait)' ELSE 'Uninterruptible sleep (不可中断等待)' END
    WHEN 'DK' THEN CASE WHEN io_wait = 1 THEN 'Uninterruptible sleep (kernel io_wait)' ELSE 'Uninterruptible sleep (kernel wait)' END
    ELSE state
  END as state_desc,
  ROUND(SUM(clipped_dur) / 1e6, 2) as total_dur_ms,
  ROUND(100.0 * SUM(clipped_dur) / NULLIF(MAX(startup_dur), 0), 1) as percent,
  COUNT(*) as count,
  io_wait,
  CASE
    WHEN state IN ('D', 'DK') AND io_wait = 1 THEN 'direct_io_wait'
    WHEN state IN ('D', 'DK') AND (
      EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE blocked_function_lc GLOB f.pattern)
    ) THEN 'inferred_io_or_page_cache'
    WHEN state IN ('D', 'DK') THEN 'ambiguous_uninterruptible_wait'
    WHEN state = 'S' AND (blocked_function_lc LIKE '%epoll%' OR blocked_function_lc LIKE '%poll%') THEN 'poll_idle_or_ambiguous'
    WHEN state = 'S' AND (blocked_function_lc LIKE '%futex%' OR blocked_function_lc LIKE '%mutex%' OR blocked_function_lc LIKE '%monitor%') THEN 'lock_wait'
    WHEN blocked_function_lc LIKE '%binder%' THEN 'binder_wait'
    ELSE 'state_only'
  END as evidence_strength,
  blocked_function as blocked_functions
FROM state_rows
WHERE clipped_dur > 0
GROUP BY startup_id, state, io_wait, blocked_function
ORDER BY total_dur_ms DESC

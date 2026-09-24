-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 376ae3d00765275d36e436290949e64c85af55dccfe476e25630487f4b50c2bb
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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
io_wait_states AS (
  SELECT
    ts.utid, ts.ts, ts.dur, ts.state, ts.blocked_function, ts.io_wait
  FROM thread_state ts
  WHERE ts.state IN ('D', 'DK')
    AND (
      COALESCE(ts.io_wait, 0) = 1
      OR EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE LOWER(COALESCE(ts.blocked_function, '')) GLOB f.pattern)
    )
    AND ts.dur > ${min_duration_ms|1} * 1e6
    AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
)
SELECT
  COUNT(*) as io_wait_events,
  ROUND(SUM(dur) / 1e6, 2) as total_io_wait_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_io_wait_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_io_wait_ms,
  COUNT(DISTINCT utid) as affected_threads,
  CASE
    WHEN SUM(dur) / 1e6 > ${critical_io_wait_ms|5000} THEN 'critical'
    WHEN SUM(dur) / 1e6 > ${warning_io_wait_ms|1000} THEN 'warning'
    WHEN SUM(dur) / 1e6 > 100 THEN 'info'
    ELSE 'normal'
  END as severity
FROM io_wait_states

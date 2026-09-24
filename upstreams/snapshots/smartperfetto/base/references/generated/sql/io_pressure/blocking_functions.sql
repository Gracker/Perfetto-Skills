-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 376ae3d00765275d36e436290949e64c85af55dccfe476e25630487f4b50c2bb
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
SELECT
  COALESCE(blocked_function, 'unknown') as blocked_function,
  COUNT(*) as block_count,
  ROUND(SUM(dur) / 1e6, 2) as total_block_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_block_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_block_ms,
  CASE
    WHEN blocked_function LIKE '%f2fs%' OR blocked_function LIKE '%ext4%' THEN 'filesystem'
    WHEN blocked_function LIKE '%read%' OR blocked_function LIKE '%write%' THEN 'read_write'
    WHEN blocked_function LIKE '%sync%' OR blocked_function LIKE '%fsync%' THEN 'sync'
    WHEN blocked_function LIKE '%io%' OR blocked_function LIKE '%blk%' THEN 'block_io'
    ELSE 'other'
  END as category
FROM thread_state
WHERE state IN ('D', 'DK')
  AND (
    COALESCE(io_wait, 0) = 1
    OR EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE LOWER(COALESCE(blocked_function, '')) GLOB f.pattern)
  )
  AND dur > ${min_duration_ms|1} * 1e6
  AND blocked_function IS NOT NULL
  AND blocked_function != ''
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY blocked_function
ORDER BY total_block_ms DESC
LIMIT ${max_items|20}

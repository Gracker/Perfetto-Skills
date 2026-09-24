-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 376ae3d00765275d36e436290949e64c85af55dccfe476e25630487f4b50c2bb
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

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
io_by_process AS (
  SELECT
    p.name as process_name, p.pid,
    SUM(ts.dur) / 1e6 as io_wait_ms,
    COUNT(*) as io_events,
    AVG(ts.dur) / 1e6 as avg_wait_ms
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ts.state IN ('D', 'DK')
    AND (
      COALESCE(ts.io_wait, 0) = 1
      OR EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE LOWER(COALESCE(ts.blocked_function, '')) GLOB f.pattern)
    )
    AND ts.dur > ${min_duration_ms|1} * 1e6
    AND ('${package}' = '' OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*'))
    AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
  GROUP BY p.upid
),
totals AS (
  SELECT SUM(io_wait_ms) as total_io_wait_ms FROM io_by_process
)
SELECT
  process_name, pid,
  ROUND(io_wait_ms, 2) as io_wait_ms,
  io_events,
  ROUND(avg_wait_ms, 2) as avg_wait_ms,
  ROUND(io_wait_ms * 100.0 / NULLIF((SELECT total_io_wait_ms FROM totals), 0), 1) as pct_of_total
FROM io_by_process
ORDER BY io_wait_ms DESC
LIMIT ${max_items|20}

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: bccf60688175843149ed487af73b20b0262476eef680d9ae13a75bd1ee234846
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
  t.name AS thread_name,
  CAST(SUM(ts.dur) / 1e6 AS INTEGER) AS io_wait_ms,
  COUNT(*) AS io_wait_count,
  CAST(AVG(ts.dur) / 1e6 AS REAL) AS avg_wait_ms
FROM thread_state ts
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND ts.state IN ('D', 'DK')  -- Uninterruptible sleep; io_wait/function pattern required for IO attribution
  AND (
    COALESCE(ts.io_wait, 0) = 1
    OR EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE LOWER(COALESCE(ts.blocked_function, '')) GLOB f.pattern)
  )
  AND ts.dur > 1000000
GROUP BY t.utid
HAVING io_wait_ms > 5
ORDER BY io_wait_ms DESC
LIMIT 15

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/io_blocked_function_families.sql
-- Source SHA-256: 2610f0d4a9fdc3232af16c2e9459a360a97100d7c7a2890167a5d535590c878a
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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

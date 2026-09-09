-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 89b4d18013a6f905876e70327ad35d2b6b486969311b984b2eabdcf58eeffa90
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
target_threads AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.tid = p.pid OR t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster' OR t.name GLOB '[0-9]*.ui')
),
io_states AS (
  SELECT
    tt.thread_name,
    ts.dur,
    ts.state,
    ts.io_wait,
    ts.blocked_function
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  WHERE ts.ts >= ${start_ts}
    AND ts.ts < ${end_ts}
    AND ts.state IN ('D', 'DK')
    AND (
      COALESCE(ts.io_wait, 0) = 1
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%folio_wait%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%sync%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%f2fs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%erofs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ufshcd%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%mmc_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%dm_%'
    )
    AND ts.dur > 100000
)
SELECT
  thread_name,
  COUNT(*) as blocked_count,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_ms,
  MAX(io_wait) as io_wait,
  CASE
    WHEN MAX(io_wait) = 1 THEN 'direct_io_wait'
    ELSE 'inferred_io_or_page_cache'
  END as evidence_strength,
  COALESCE(
    MAX(blocked_function),
    CASE WHEN MAX(io_wait) = 1 THEN 'IO wait' ELSE 'kernel wait' END
  ) as io_cause
FROM io_states
GROUP BY thread_name
HAVING total_ms > 0.1
ORDER BY total_ms DESC

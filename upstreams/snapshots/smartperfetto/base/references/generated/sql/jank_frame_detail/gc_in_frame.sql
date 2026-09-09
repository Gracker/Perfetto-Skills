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
gc_events AS (
  SELECT
    gc.tid,
    gc.gc_type,
    gc.gc_ts as gc_ts,
    gc.gc_dur as gc_dur,
    -- Calculate overlap with frame window
    MAX(gc.gc_ts, ${start_ts}) as overlap_start,
    MIN(gc.gc_ts + gc.gc_dur, ${end_ts}) as overlap_end
  FROM android_garbage_collection_events gc
  JOIN effective_target_processes p ON gc.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND gc.gc_ts < ${end_ts}
    AND gc.gc_ts + gc.gc_dur > ${start_ts}
)
SELECT
  gc_type,
  COUNT(*) as gc_count,
  ROUND(SUM(gc_dur) / 1e6, 2) as total_dur_ms,
  ROUND(SUM(CASE WHEN overlap_end > overlap_start THEN overlap_end - overlap_start ELSE 0 END) / 1e6, 2) as overlap_ms,
  ROUND(MAX(gc_dur) / 1e6, 2) as max_dur_ms
FROM gc_events
GROUP BY gc_type
HAVING overlap_ms > 0
ORDER BY overlap_ms DESC

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 89b4d18013a6f905876e70327ad35d2b6b486969311b984b2eabdcf58eeffa90
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.tid = p.pid OR t.name GLOB '[0-9]*.ui')
)
SELECT
  s.name,
  ROUND(SUM(s.dur) / 1e6, 2) as dur_ms,
  COUNT(*) as count,
  ROUND(MAX(s.dur) / 1e6, 2) as max_ms,
  printf('%d', MIN(s.ts)) as ts
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
WHERE tt.utid IN (SELECT utid FROM main_thread)
  AND s.ts >= COALESCE(${main_start_ts}, ${start_ts})
  AND s.ts < COALESCE(${main_end_ts}, ${end_ts})
  AND s.dur >= 1000000
  AND s.name NOT GLOB '*resynced*'
GROUP BY s.name
HAVING dur_ms > 1
ORDER BY dur_ms DESC
LIMIT 10

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 2dcba698d9cc63e045e9346afc44cab60148cf55a58161bf0378383d624af4ff
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
frame_bounds AS (
  SELECT
    MIN(a.ts) as min_ts,
    MAX(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END) as max_ts
  FROM actual_frame_timeline_slice a
  JOIN effective_target_processes p ON a.upid = p.upid
  WHERE (
    ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}'
    OR p.name GLOB '${package}:*'
  )
    AND p.name NOT LIKE '/system/%'
    -- With no target package the clause above accepts any process, and
    -- the system UI is the one most likely to be drawing while the target
    -- app draws nothing. Its frames are punctual, so they read back as
    -- flawless scrolling for an app that produced no frames at all: one
    -- device reported 31fps SystemUI frames as "优秀", another rated a
    -- 5-frame notification-shade window. Anyone analysing the system UI
    -- deliberately names it and keeps these rows.
    AND ('${package}' != '' OR p.name NOT LIKE 'com.android.systemui%')
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
)
SELECT
  CASE
    WHEN COALESCE(${start_ts}, min_ts) IS NOT NULL
      THEN printf('%d', COALESCE(${start_ts}, min_ts))
    ELSE NULL
  END as window_start_ts,
  CASE
    WHEN COALESCE(${end_ts}, max_ts) IS NOT NULL
      THEN printf('%d', COALESCE(${end_ts}, max_ts))
    ELSE NULL
  END as window_end_ts,
  CASE
    WHEN COALESCE(${start_ts}, min_ts) IS NOT NULL
      AND COALESCE(${end_ts}, max_ts) IS NOT NULL
      THEN ROUND((COALESCE(${end_ts}, max_ts) - COALESCE(${start_ts}, min_ts)) / 1e6, 2)
    ELSE NULL
  END as window_ms,
  CASE
    WHEN ${start_ts} IS NOT NULL OR ${end_ts} IS NOT NULL THEN 'user_selected'
    WHEN min_ts IS NOT NULL AND max_ts IS NOT NULL THEN 'auto_frame_bounds'
    ELSE 'unavailable'
  END as window_source
FROM frame_bounds

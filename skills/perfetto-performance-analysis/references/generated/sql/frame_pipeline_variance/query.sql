-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_pipeline_variance.skill.yaml
-- Source SHA-256: 758727e5e7fe862de5324469e2a8006fa72f121bba6818661575c1f97dfbd823
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
frames AS (
  SELECT
    a.ts,
    a.dur / 1e6 as frame_ms
  FROM actual_frame_timeline_slice a
  JOIN effective_target_processes p ON a.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
),
deltas AS (
  SELECT
    ts,
    frame_ms,
    ABS(frame_ms - LAG(frame_ms) OVER (ORDER BY ts)) as delta_ms
  FROM frames
)
SELECT
  COUNT(*) as total_frames,
  ROUND(AVG(frame_ms), 2) as avg_frame_ms,
  ROUND(SQRT(MAX(AVG(frame_ms * frame_ms) - AVG(frame_ms) * AVG(frame_ms), 0)), 2) as stddev_ms,
  ROUND(AVG(COALESCE(delta_ms, 0)), 2) as avg_delta_ms,
  SUM(CASE WHEN COALESCE(delta_ms, 0) >= ${transition_threshold_ms|8} THEN 1 ELSE 0 END) as high_variance_transitions,
  CASE
    WHEN AVG(COALESCE(delta_ms, 0)) >= ${transition_threshold_ms|8} THEN 'high'
    WHEN AVG(COALESCE(delta_ms, 0)) >= ${transition_threshold_ms|8} * 0.5 THEN 'medium'
    ELSE 'low'
  END as variance_level
FROM deltas

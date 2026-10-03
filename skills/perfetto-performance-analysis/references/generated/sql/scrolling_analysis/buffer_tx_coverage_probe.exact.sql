-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 8016df273414d989f2aaa25e0e34647bbb695e925fcdcb07a400e74b9a806728

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
target_presence AS (
  SELECT COUNT(*) AS target_process_count FROM effective_target_processes
), frame_coverage AS (
  SELECT COUNT(DISTINCT COALESCE(CAST(a.display_frame_token AS TEXT),
    'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT))) AS frame_timeline_frames
  FROM actual_frame_timeline_slice a
  JOIN effective_target_processes p ON a.upid = p.upid
  WHERE (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
), probe_coverage AS (
SELECT target_process_count,
  CASE WHEN target_process_count > 0 THEN 'found' ELSE 'not_found' END AS target_process_status,
  frame_timeline_frames,
  NULL AS buffer_tx_frames, NULL AS frame_timeline_to_buffer_tx_ratio,
  NULL AS buffer_tx_track_id, NULL AS frame_source_track,
  NULL AS buffer_tx_effective_span_ns,
  CASE WHEN target_process_count = 0 THEN 'target_process_not_found'
    WHEN frame_timeline_frames = 0 THEN 'no_frame_timeline_coverage'
    ELSE 'frame_timeline_only_exact_upid' END AS coverage_status,
  0 AS should_fallback,
  'unavailable_exact_upid' AS buffer_tx_status
FROM target_presence CROSS JOIN frame_coverage
)
-- Exact-UPID scope never compares against BufferTX.
SELECT target_process_count, target_process_status, frame_timeline_frames,
  buffer_tx_frames, frame_timeline_to_buffer_tx_ratio, buffer_tx_track_id,
  frame_source_track, buffer_tx_effective_span_ns, coverage_status,
  should_fallback, buffer_tx_status,
  CASE coverage_status
    WHEN 'sufficient_frame_timeline_coverage' THEN 'full_frame_timeline'
    WHEN 'partial_frame_timeline_coverage' THEN 'partial_sample'
    WHEN 'no_buffer_tx_candidate' THEN 'frame_timeline_only_unbenchmarked'
    WHEN 'frame_timeline_only_exact_upid' THEN 'frame_timeline_only_unbenchmarked'
    ELSE 'coverage_unverified'
  END AS root_cause_evidence_scope
FROM probe_coverage

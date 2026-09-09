-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/main_thread_work_cadence.sql
-- Source SHA-256: 650753d77afb15269982dec24102d71fa8a92c18da803538a9390a285a9f18c8
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Depends on main_thread_work.sql. Observed starts are not requested deadlines,
-- display presentation timestamps, or evidence that every interval needed a frame.
mtw_frame_starts AS (
  SELECT f.upid, f.utid, f.raw_ts, COUNT(*) AS marker_count,
    CASE WHEN COUNT(*) = 1 THEN MIN(f.slice_id) END AS slice_id,
    CASE WHEN COUNT(*) = 1 AND MAX(f.is_incomplete) = 0 THEN MAX(f.raw_ts + f.raw_dur) END AS execution_end_ts,
    MAX(f.is_incomplete) AS is_incomplete
  FROM mtw_frames f JOIN mtw_threads t USING (utid)
  WHERE f.raw_ts >= t.window_start_ts AND f.raw_ts < t.window_end_ts
  GROUP BY f.utid, f.raw_ts
),
mtw_frame_sequence AS (
  SELECT *, LAG(raw_ts) OVER w AS previous_start_ts,
    LAG(slice_id) OVER w AS previous_slice_id,
    LAG(execution_end_ts) OVER w AS previous_end_ts,
    LAG(marker_count) OVER w AS previous_marker_count,
    LAG(is_incomplete) OVER w AS previous_is_incomplete
  FROM mtw_frame_starts WINDOW w AS (PARTITION BY utid ORDER BY raw_ts)
),
mtw_cadence_ranked AS (
  SELECT *, COUNT(*) OVER () AS eligible_interval_count,
    ROW_NUMBER() OVER (ORDER BY raw_ts - previous_start_ts DESC, utid, raw_ts) AS interval_rank
  FROM mtw_frame_sequence WHERE previous_start_ts IS NOT NULL
),
main_thread_work_cadence_output AS (
  SELECT upid, utid, previous_slice_id, slice_id, printf('%d', previous_start_ts) AS start_ts,
    printf('%d', raw_ts) AS next_start_ts, printf('%d', raw_ts - previous_start_ts) AS dur,
    (raw_ts - previous_start_ts) / 1e6 AS observed_start_interval_ms,
    CASE WHEN marker_count = 1 AND previous_marker_count = 1 AND previous_end_ts IS NOT NULL
      THEN MAX(0, raw_ts - previous_end_ts) / 1e6 END AS between_execution_ms,
    CASE WHEN marker_count = 1 AND previous_marker_count = 1 AND previous_end_ts IS NOT NULL
      THEN MAX(0, previous_end_ts - raw_ts) / 1e6 END AS execution_overlap_ms,
    marker_count, previous_marker_count, is_incomplete, previous_is_incomplete,
    CASE WHEN marker_count > 1 OR previous_marker_count > 1 THEN 'ambiguous_duplicate_markers'
      WHEN previous_is_incomplete = 1 THEN 'incomplete_previous_execution'
      ELSE 'observed_start_interval' END AS observation,
    eligible_interval_count,
    MIN(eligible_interval_count, (SELECT top_k FROM mtw_config)) AS returned_interval_count,
    'largest observed doFrame start intervals; request, deadline, presentation and missed frames are not inferred' AS evidence_scope
  FROM mtw_cadence_ranked WHERE interval_rank <= (SELECT top_k FROM mtw_config)
)

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/main_thread_frame_work.skill.yaml
-- Source SHA-256: 5b782c252c80af2d4d445da11db4f32db6b09a78f4e8c5ef19dd24fbbf7f201b
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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Continuous main-thread evidence. FrameTimeline is deliberately not an input.
-- Only scoped root annotations, doFrames and scheduler states enter the sweep;
-- nested slices never multiply wall/CPU totals. All intervals are half-open.
-- Explicitly materialize reusable scoped relations: the Perfetto virtual-table
-- planner otherwise re-expands these joins in recursive and integral consumers.
mtw_config AS MATERIALIZED (
  SELECT COALESCE(${start_ts}, start_ts) AS start_ts,
    COALESCE(${end_ts}, end_ts) AS end_ts,
    MIN(100, MAX(1, CAST(COALESCE(${main_thread_top_k|20}, 20) AS INTEGER))) AS top_k
  FROM trace_bounds
),
mtw_threads AS MATERIALIZED (
  SELECT p.upid, p.pid, p.name AS process_name, t.utid, t.tid,
    MAX(c.start_ts, COALESCE(p.start_ts, c.start_ts), COALESCE(t.start_ts, c.start_ts)) AS window_start_ts,
    MIN(c.end_ts, COALESCE(p.end_ts, c.end_ts), COALESCE(t.end_ts, c.end_ts)) AS window_end_ts
  FROM effective_target_processes p
  JOIN thread t ON t.upid = p.upid AND t.tid = p.pid
  CROSS JOIN mtw_config c
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND window_start_ts < window_end_ts
),
mtw_slices AS MATERIALIZED (
  SELECT s.id AS slice_id, s.name AS task_name, s.parent_id, s.arg_set_id,
    s.track_id, t.upid, t.utid, s.ts AS raw_ts, s.dur AS raw_dur,
    MAX(s.ts, t.window_start_ts) AS start_ts,
    MIN(CASE WHEN s.dur = -1 THEN t.window_end_ts ELSE s.ts + s.dur END,
      t.window_end_ts) AS end_ts,
    CASE WHEN s.dur = -1 THEN 1 ELSE 0 END AS is_incomplete,
    CASE WHEN (s.name GLOB 'Choreographer#doFrame*' OR s.name = 'doFrame')
      AND LOWER(s.name) NOT GLOB '*resynced*' THEN 1 ELSE 0 END AS is_doframe
  FROM mtw_threads t
  JOIN thread_track tt ON tt.utid = t.utid
  JOIN slice s ON s.track_id = tt.id
  WHERE s.ts < t.window_end_ts AND (s.dur > 0 OR s.dur = -1)
    AND (s.dur = -1 OR s.ts + s.dur > t.window_start_ts)
),
mtw_roots AS MATERIALIZED (
  -- An observed root is an annotation, not proof of one Looper message.
  SELECT s.* FROM mtw_slices s
  LEFT JOIN mtw_slices parent ON parent.slice_id = s.parent_id
    AND parent.track_id = s.track_id AND parent.utid = s.utid
  WHERE parent.slice_id IS NULL
),
mtw_frame_ancestors AS (
  SELECT slice_id AS frame_slice_id, parent_id, track_id FROM mtw_slices WHERE is_doframe = 1
  UNION ALL
  SELECT a.frame_slice_id, p.parent_id, a.track_id
  FROM mtw_frame_ancestors a JOIN mtw_slices p ON p.slice_id = a.parent_id AND p.track_id = a.track_id
),
mtw_frames AS MATERIALIZED (
  SELECT f.* FROM mtw_slices f WHERE f.is_doframe = 1
    AND NOT EXISTS (SELECT 1 FROM mtw_frame_ancestors a
      JOIN mtw_slices p ON p.slice_id = a.parent_id AND p.track_id = a.track_id
      WHERE a.frame_slice_id = f.slice_id AND p.is_doframe = 1)
),
mtw_states AS MATERIALIZED (
  SELECT s.id AS state_id, t.utid, s.state, s.blocked_function,
    s.io_wait AS raw_io_wait, s.ts AS raw_ts, s.dur AS raw_dur,
    MAX(s.ts, t.window_start_ts) AS start_ts,
    MIN(CASE WHEN s.dur = -1 THEN t.window_end_ts ELSE s.ts + s.dur END,
      t.window_end_ts) AS end_ts,
    CASE s.state WHEN 'Running' THEN 'running' WHEN 'R' THEN 'runnable'
      WHEN 'R+' THEN 'runnable_preempted' WHEN 'S' THEN 'sleep'
      WHEN 'I' THEN 'idle_state' WHEN 'D' THEN 'uninterruptible'
      WHEN 'DK' THEN 'uninterruptible_wakekill' ELSE 'other_state' END AS kind,
    CASE WHEN s.state IN ('D', 'DK') THEN s.io_wait END AS io_wait
  FROM mtw_threads t JOIN thread_state s ON s.utid = t.utid
  WHERE s.ts < t.window_end_ts AND (s.dur > 0 OR s.dur = -1)
    AND (s.dur = -1 OR s.ts + s.dur > t.window_start_ts)
),
mtw_intervals AS (
  SELECT utid, start_ts, end_ts, 'annotation' AS kind FROM mtw_roots
  UNION ALL SELECT utid, start_ts, end_ts, 'doframe' FROM mtw_frames
  UNION ALL SELECT utid, start_ts, end_ts, kind FROM mtw_states
  UNION ALL SELECT utid, start_ts, end_ts, 'io_wait' FROM mtw_states WHERE io_wait = 1
  UNION ALL SELECT utid, start_ts, end_ts, 'unknown_io_wait' FROM mtw_states
    WHERE kind IN ('uninterruptible', 'uninterruptible_wakekill') AND io_wait IS NULL
),
mtw_events AS (
  SELECT utid, start_ts AS ts, kind, 1 AS delta FROM mtw_intervals
  UNION ALL SELECT utid, end_ts, kind, -1 FROM mtw_intervals
  UNION ALL SELECT utid, window_start_ts, 'boundary', 0 FROM mtw_threads
  UNION ALL SELECT utid, window_end_ts, 'boundary', 0 FROM mtw_threads
  -- Zero-delta annotation endpoints let task/hotspot integrals use equality
  -- joins. This adds O(scoped slices) events, never endpoints x all slices.
  UNION ALL SELECT utid, start_ts, 'boundary', 0 FROM mtw_slices
  UNION ALL SELECT utid, end_ts, 'boundary', 0 FROM mtw_slices
),
mtw_event_deltas AS (
  SELECT utid, ts,
    SUM(CASE WHEN kind = 'annotation' THEN delta ELSE 0 END) AS annotation,
    SUM(CASE WHEN kind = 'doframe' THEN delta ELSE 0 END) AS doframe,
    SUM(CASE WHEN kind = 'running' THEN delta ELSE 0 END) AS running,
    SUM(CASE WHEN kind = 'runnable' THEN delta ELSE 0 END) AS runnable,
    SUM(CASE WHEN kind = 'runnable_preempted' THEN delta ELSE 0 END) AS runnable_preempted,
    SUM(CASE WHEN kind = 'sleep' THEN delta ELSE 0 END) AS sleep,
    SUM(CASE WHEN kind = 'idle_state' THEN delta ELSE 0 END) AS idle_state,
    SUM(CASE WHEN kind = 'uninterruptible' THEN delta ELSE 0 END) AS uninterruptible,
    SUM(CASE WHEN kind = 'uninterruptible_wakekill' THEN delta ELSE 0 END) AS uninterruptible_wakekill,
    SUM(CASE WHEN kind = 'other_state' THEN delta ELSE 0 END) AS other_state,
    SUM(CASE WHEN kind = 'io_wait' THEN delta ELSE 0 END) AS io_wait,
    SUM(CASE WHEN kind = 'unknown_io_wait' THEN delta ELSE 0 END) AS unknown_io_wait
  FROM mtw_events GROUP BY utid, ts
),
mtw_sweep AS (
  SELECT utid, ts AS start_ts, LEAD(ts) OVER w AS end_ts,
    SUM(annotation) OVER w AS annotation, SUM(doframe) OVER w AS doframe,
    SUM(running) OVER w AS running, SUM(runnable) OVER w AS runnable,
    SUM(runnable_preempted) OVER w AS runnable_preempted,
    SUM(sleep) OVER w AS sleep, SUM(idle_state) OVER w AS idle_state,
    SUM(uninterruptible) OVER w AS uninterruptible,
    SUM(uninterruptible_wakekill) OVER w AS uninterruptible_wakekill,
    SUM(other_state) OVER w AS other_state, SUM(io_wait) OVER w AS io_wait,
    SUM(unknown_io_wait) OVER w AS unknown_io_wait
  FROM mtw_event_deltas
  WINDOW w AS (PARTITION BY utid ORDER BY ts ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
),
mtw_frame_bounds AS (
  SELECT utid, MIN(start_ts) AS first_frame_start, MAX(end_ts) AS last_frame_end,
    COUNT(*) AS observed_doframe_count FROM mtw_frames GROUP BY utid
),
mtw_segments AS MATERIALIZED (
  SELECT s.*,
    CASE WHEN f.utid IS NULL THEN 'no_doFrame' WHEN s.doframe > 0 THEN 'inside_doFrame'
      WHEN s.start_ts < f.first_frame_start THEN 'before_first_doFrame'
      WHEN s.start_ts >= f.last_frame_end THEN 'after_last_doFrame'
      ELSE 'between_doFrames' END AS phase,
    (s.running > 0) + (s.runnable > 0) + (s.runnable_preempted > 0) + (s.sleep > 0)
      + (s.idle_state > 0) + (s.uninterruptible > 0)
      + (s.uninterruptible_wakekill > 0) + (s.other_state > 0) AS state_kind_count
  FROM mtw_sweep s LEFT JOIN mtw_frame_bounds f USING (utid)
  WHERE s.end_ts > s.start_ts
),
mtw_segment_integrals AS (
  SELECT utid, start_ts, end_ts,
    SUM(CASE WHEN phase != 'inside_doFrame' THEN end_ts - start_ts ELSE 0 END)
      OVER (PARTITION BY utid ORDER BY start_ts ROWS UNBOUNDED PRECEDING) AS outside_at_end_ns,
    CASE WHEN phase != 'inside_doFrame' THEN end_ts - start_ts ELSE 0 END AS outside_ns
  FROM mtw_segments
),
mtw_outside_integrals AS MATERIALIZED (
  SELECT utid, start_ts AS ts, outside_at_end_ns - outside_ns AS outside_ns FROM mtw_segment_integrals
  UNION ALL
  SELECT s.utid, s.end_ts, s.outside_at_end_ns FROM mtw_segment_integrals s
    JOIN mtw_threads t ON s.utid = t.utid AND s.end_ts = t.window_end_ts
),
mtw_summary_segments AS (
  SELECT *, phase AS summary_phase FROM mtw_segments
  UNION ALL SELECT *, 'window' FROM mtw_segments
),
mtw_coverage AS (
  SELECT t.utid, COUNT(s.slice_id) AS observed_slice_count,
    COUNT(DISTINCT s.track_id) AS annotation_track_count,
    COALESCE(SUM(s.is_incomplete), 0) AS incomplete_slice_count,
    (SELECT COUNT(*) FROM mtw_roots r WHERE r.utid = t.utid) AS eligible_task_count
  FROM mtw_threads t LEFT JOIN mtw_slices s USING (utid) GROUP BY t.utid
),
main_thread_work_summary AS (
  SELECT t.upid, t.pid, t.process_name, t.utid, t.tid,
    printf('%d', t.window_start_ts) AS window_start_ts,
    printf('%d', t.window_end_ts) AS window_end_ts, s.summary_phase AS phase,
    SUM(s.end_ts - s.start_ts) / 1e6 AS wall_ms,
    SUM(CASE WHEN annotation > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 AS annotated_wall_ms,
    SUM(CASE WHEN annotation = 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 AS unannotated_wall_ms,
    SUM(CASE WHEN annotation > 1 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 AS ambiguous_annotation_wall_ms,
    SUM(CASE WHEN state_kind_count = 1 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 AS known_state_ms,
    SUM(CASE WHEN state_kind_count != 1 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 AS unknown_state_ms,
    SUM(CASE WHEN state_kind_count > 1 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 AS conflicting_state_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND running > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS running_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND runnable > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS runnable_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND runnable_preempted > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS runnable_preempted_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND sleep > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS sleep_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND idle_state > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS idle_state_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND uninterruptible > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS uninterruptible_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND uninterruptible_wakekill > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS uninterruptible_wakekill_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND other_state > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS other_state_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND io_wait > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS io_wait_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND unknown_io_wait > 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS unknown_io_wait_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN SUM(CASE WHEN state_kind_count = 1
      AND running > 0 AND annotation = 0 THEN s.end_ts - s.start_ts ELSE 0 END) / 1e6 END AS unannotated_running_ms,
    c.observed_slice_count, c.eligible_task_count, c.annotation_track_count,
    c.incomplete_slice_count, COALESCE(f.observed_doframe_count, 0) AS observed_doframe_count,
    'observed intervals; annotations are not necessarily Looper messages; no deadline or request inferred' AS evidence_scope
  FROM mtw_summary_segments s JOIN mtw_threads t USING (utid)
  JOIN mtw_coverage c USING (utid) LEFT JOIN mtw_frame_bounds f USING (utid)
  GROUP BY t.utid, s.summary_phase
)
,
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
SELECT * FROM main_thread_work_cadence_output
ORDER BY observed_start_interval_ms DESC, utid, CAST(start_ts AS INTEGER)

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

-- Depends on main_thread_work.sql. Rank observed roots after complete coverage
-- accounting. Only the bounded roots expand into descendants/state intersections.
-- Keep the reusable bounded relations materialized; dropping these fences can
-- repeat source-table scans despite logically identical CTE references.
mtw_ranked_roots AS (
  SELECT r.*, b.outside_ns - a.outside_ns AS outside_doframe_ns,
    ROW_NUMBER() OVER (ORDER BY b.outside_ns - a.outside_ns DESC,
      r.end_ts - r.start_ts DESC, r.utid, r.start_ts, r.slice_id) AS task_rank,
    COUNT(*) OVER () AS eligible_task_count
  FROM mtw_roots r
  JOIN mtw_outside_integrals a ON a.utid = r.utid AND a.ts = r.start_ts
  JOIN mtw_outside_integrals b ON b.utid = r.utid AND b.ts = r.end_ts
),
mtw_selected_roots AS MATERIALIZED (
  SELECT * FROM mtw_ranked_roots WHERE task_rank <= (SELECT top_k FROM mtw_config)
),
mtw_task_segments AS (
  SELECT r.slice_id, s.phase, s.state_kind_count, s.running, s.runnable,
    s.runnable_preempted, s.sleep, s.idle_state, s.uninterruptible,
    s.uninterruptible_wakekill, s.other_state, s.io_wait, s.unknown_io_wait,
    s.annotation, MIN(r.end_ts, s.end_ts) - MAX(r.start_ts, s.start_ts) AS dur
  FROM mtw_selected_roots r JOIN mtw_segments s ON s.utid = r.utid
    AND s.start_ts < r.end_ts AND s.end_ts > r.start_ts
),
mtw_task_totals AS MATERIALIZED (
  SELECT slice_id, CASE WHEN COUNT(DISTINCT phase) = 1 THEN MIN(phase) ELSE 'mixed' END AS phase,
    SUM(CASE WHEN phase = 'inside_doFrame' THEN dur ELSE 0 END) / 1e6 AS inside_doframe_ms,
    SUM(CASE WHEN phase = 'between_doFrames' THEN dur ELSE 0 END) / 1e6 AS between_doframes_ms,
    SUM(CASE WHEN phase = 'before_first_doFrame' THEN dur ELSE 0 END) / 1e6 AS before_first_doframe_ms,
    SUM(CASE WHEN phase = 'after_last_doFrame' THEN dur ELSE 0 END) / 1e6 AS after_last_doframe_ms,
    SUM(CASE WHEN phase = 'no_doFrame' THEN dur ELSE 0 END) / 1e6 AS no_doframe_ms,
    SUM(CASE WHEN phase != 'inside_doFrame' THEN dur ELSE 0 END) / 1e6 AS outside_doframe_ms,
    SUM(CASE WHEN state_kind_count != 1 THEN dur ELSE 0 END) / 1e6 AS unknown_state_ms,
    SUM(CASE WHEN annotation > 1 THEN dur ELSE 0 END) / 1e6 AS ambiguous_annotation_wall_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND running > 0 THEN dur ELSE 0 END) / 1e6 END AS running_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND runnable > 0 THEN dur ELSE 0 END) / 1e6 END AS runnable_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND runnable_preempted > 0 THEN dur ELSE 0 END) / 1e6 END AS runnable_preempted_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND sleep > 0 THEN dur ELSE 0 END) / 1e6 END AS sleep_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND idle_state > 0 THEN dur ELSE 0 END) / 1e6 END AS idle_state_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND uninterruptible + uninterruptible_wakekill > 0 THEN dur ELSE 0 END) / 1e6 END AS uninterruptible_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND io_wait > 0 THEN dur ELSE 0 END) / 1e6 END AS io_wait_ms,
    CASE WHEN SUM(state_kind_count = 1) > 0 THEN
      SUM(CASE WHEN state_kind_count = 1 AND unknown_io_wait > 0 THEN dur ELSE 0 END) / 1e6 END AS unknown_io_wait_ms
  FROM mtw_task_segments GROUP BY slice_id
),
mtw_task_descendants AS MATERIALIZED (
  SELECT slice_id AS root_slice_id, slice_id, task_name, parent_id, arg_set_id,
    track_id, utid, start_ts, end_ts, is_incomplete, is_doframe AS in_doframe_tree,
    CAST(task_name AS TEXT) AS ancestor_path
  FROM mtw_selected_roots
  UNION ALL
  SELECT p.root_slice_id, c.slice_id, c.task_name, c.parent_id, c.arg_set_id,
    c.track_id, c.utid, c.start_ts, c.end_ts, c.is_incomplete,
    MAX(p.in_doframe_tree, c.is_doframe),
    SUBSTR(p.ancestor_path || ' > ' || c.task_name, 1, 2048)
  FROM mtw_task_descendants p JOIN mtw_slices c ON c.parent_id = p.slice_id
    AND c.track_id = p.track_id AND c.utid = p.utid
),
mtw_direct_children AS (
  SELECT p.slice_id AS owner_slice_id, c.slice_id,
    MAX(p.start_ts, c.start_ts) AS start_ts, MIN(p.end_ts, c.end_ts) AS end_ts
  FROM mtw_task_descendants p JOIN mtw_task_descendants c ON c.parent_id = p.slice_id
    AND c.track_id = p.track_id AND c.root_slice_id = p.root_slice_id
  WHERE c.start_ts < p.end_ts AND c.end_ts > p.start_ts
),
mtw_children_prior_end AS (
  SELECT *, MAX(end_ts) OVER (PARTITION BY owner_slice_id ORDER BY start_ts, end_ts, slice_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prior_end
  FROM mtw_direct_children
),
mtw_child_union AS MATERIALIZED (
  -- Running MAX, not LAG(end): nested/overlapping siblings cannot over-subtract.
  SELECT c.owner_slice_id,
    SUM(MAX(0, c.end_ts - MAX(c.start_ts, COALESCE(c.prior_end, c.start_ts)))) AS covered_ns,
    SUM(CASE WHEN c.end_ts > MAX(c.start_ts, COALESCE(c.prior_end, c.start_ts))
      THEN b.outside_ns - a.outside_ns ELSE 0 END) AS covered_outside_ns
  FROM mtw_children_prior_end c JOIN mtw_task_descendants d ON d.slice_id = c.owner_slice_id
  JOIN mtw_outside_integrals a ON a.utid = d.utid AND a.ts = MAX(c.start_ts, COALESCE(c.prior_end, c.start_ts))
  JOIN mtw_outside_integrals b ON b.utid = d.utid AND b.ts = c.end_ts
  GROUP BY c.owner_slice_id
),
mtw_exclusive_hotspots AS (
  SELECT d.*, MAX(0, d.end_ts - d.start_ts - COALESCE(c.covered_ns, 0)) AS exclusive_wall_ns,
    MAX(0, b.outside_ns - a.outside_ns - COALESCE(c.covered_outside_ns, 0)) AS exclusive_outside_ns
  FROM mtw_task_descendants d LEFT JOIN mtw_child_union c ON c.owner_slice_id = d.slice_id
  JOIN mtw_outside_integrals a ON a.utid = d.utid AND a.ts = d.start_ts
  JOIN mtw_outside_integrals b ON b.utid = d.utid AND b.ts = d.end_ts
),
mtw_hotspots AS MATERIALIZED (
  SELECT d.*,
    ROW_NUMBER() OVER (PARTITION BY d.root_slice_id ORDER BY
      d.exclusive_outside_ns DESC, d.exclusive_wall_ns DESC, d.slice_id) AS hotspot_rank
  FROM mtw_exclusive_hotspots d
),
mtw_hotspot_evidence AS (
  SELECT root_slice_id, json_group_array(json_object(
    'slice_id', slice_id, 'name', task_name, 'parent_id', parent_id, 'arg_set_id', arg_set_id,
    'track_id', track_id, 'start_ts', printf('%d', start_ts), 'end_ts', printf('%d', end_ts),
    'exclusive_wall_ms', exclusive_wall_ns / 1e6, 'exclusive_outside_doframe_ms', exclusive_outside_ns / 1e6,
    'in_doframe_tree', in_doframe_tree, 'incomplete', is_incomplete, 'ancestor_path', ancestor_path
  )) AS hotspot_evidence
  FROM (SELECT * FROM mtw_hotspots WHERE hotspot_rank <= 3 ORDER BY root_slice_id, hotspot_rank)
  GROUP BY root_slice_id
),
mtw_task_waits AS MATERIALIZED (
  SELECT r.slice_id AS root_slice_id, s.*,
    MAX(r.start_ts, s.start_ts) AS overlap_start_ts, MIN(r.end_ts, s.end_ts) AS overlap_end_ts,
    ROW_NUMBER() OVER (PARTITION BY r.slice_id ORDER BY
      MIN(r.end_ts, s.end_ts) - MAX(r.start_ts, s.start_ts) DESC, s.start_ts, s.state_id) AS wait_rank
  FROM mtw_selected_roots r JOIN mtw_states s ON s.utid = r.utid
    AND s.start_ts < r.end_ts AND s.end_ts > r.start_ts AND s.kind != 'running'
),
mtw_wait_evidence AS (
  SELECT root_slice_id, json_group_array(json_object(
    'thread_state_id', state_id, 'state', state, 'blocked_function', blocked_function, 'io_wait', raw_io_wait,
    'raw_ts', printf('%d', raw_ts), 'raw_dur', printf('%d', raw_dur),
    'start_ts', printf('%d', overlap_start_ts), 'end_ts', printf('%d', overlap_end_ts),
    'overlap_ms', (overlap_end_ts - overlap_start_ts) / 1e6
  )) AS wait_evidence
  FROM (SELECT * FROM mtw_task_waits WHERE wait_rank <= 3 ORDER BY root_slice_id, wait_rank)
  GROUP BY root_slice_id
),
main_thread_work_task_output AS (
  SELECT r.task_name, x.phase, x.outside_doframe_ms, r.slice_id, r.upid, r.utid,
    r.track_id, r.parent_id, r.arg_set_id, printf('%d', r.raw_ts) AS raw_ts,
    printf('%d', r.raw_dur) AS raw_dur, printf('%d', r.start_ts) AS start_ts,
    printf('%d', r.end_ts) AS end_ts, printf('%d', r.end_ts - r.start_ts) AS dur,
    (r.end_ts - r.start_ts) / 1e6 AS wall_ms, r.is_incomplete,
    x.inside_doframe_ms, x.between_doframes_ms, x.before_first_doframe_ms,
    x.after_last_doframe_ms, x.no_doframe_ms,
    x.running_ms, x.runnable_ms, x.runnable_preempted_ms, x.sleep_ms,
    x.idle_state_ms, x.uninterruptible_ms, x.io_wait_ms, x.unknown_io_wait_ms,
    x.unknown_state_ms, x.ambiguous_annotation_wall_ms,
    CASE WHEN x.ambiguous_annotation_wall_ms > 0 THEN 'overlapping_roots_nonadditive'
      ELSE 'observed_root_annotation' END AS attribution,
    h.task_name AS hotspot_name, h.slice_id AS hotspot_slice_id,
    h.parent_id AS hotspot_parent_id, h.arg_set_id AS hotspot_arg_set_id,
    h.exclusive_wall_ns / 1e6 AS hotspot_exclusive_wall_ms,
    h.exclusive_outside_ns / 1e6 AS hotspot_exclusive_outside_doframe_ms,
    h.is_incomplete AS hotspot_is_incomplete, h.ancestor_path,
    e.hotspot_evidence, COALESCE(w.wait_evidence, '[]') AS wait_evidence,
    v.state_id AS top_wait_state_id, v.state AS top_wait_state,
    v.blocked_function AS top_wait_blocked_function, v.raw_io_wait AS top_wait_io_wait,
    CASE WHEN v.state_id IS NOT NULL THEN printf('%d', v.overlap_start_ts) END AS top_wait_start_ts,
    CASE WHEN v.state_id IS NOT NULL THEN printf('%d', v.overlap_end_ts) END AS top_wait_end_ts,
    (v.overlap_end_ts - v.overlap_start_ts) / 1e6 AS top_wait_overlap_ms,
    r.eligible_task_count, (SELECT COUNT(*) FROM mtw_selected_roots) AS returned_task_count,
    'roots ranked by doFrame-external wall time then total wall; top 3 exclusive hotspots and wait states per returned root; nonadditive across overlapping tracks; not proof of causality' AS selection_scope
  FROM mtw_selected_roots r JOIN mtw_task_totals x USING (slice_id)
  JOIN mtw_hotspots h ON h.root_slice_id = r.slice_id AND h.hotspot_rank = 1
  JOIN mtw_hotspot_evidence e ON e.root_slice_id = r.slice_id
  LEFT JOIN mtw_wait_evidence w ON w.root_slice_id = r.slice_id
  LEFT JOIN mtw_task_waits v ON v.root_slice_id = r.slice_id AND v.wait_rank = 1
),
main_thread_work_source_output AS (
  -- Scalar rows survive generic display/artifact string truncation. Names and
  -- paths may still be shortened, so IDs are the authority for a focused read.
  SELECT 'hotspot' AS source_kind, r.slice_id AS root_slice_id,
    r.upid, r.utid, r.track_id AS root_track_id, h.track_id,
    h.slice_id AS source_slice_id, NULL AS thread_state_id,
    h.task_name AS source_name, NULL AS state, NULL AS blocked_function, NULL AS io_wait,
    printf('%d', h.start_ts) AS start_ts, printf('%d', h.end_ts) AS end_ts,
    printf('%d', h.end_ts - h.start_ts) AS dur,
    h.exclusive_wall_ns / 1e6 AS exclusive_wall_ms,
    h.exclusive_outside_ns / 1e6 AS exclusive_outside_doframe_ms,
    NULL AS wait_overlap_ms, h.parent_id, h.arg_set_id,
    h.in_doframe_tree, h.is_incomplete, h.hotspot_rank AS source_rank,
    r.task_rank AS root_task_rank,
    'top 3 hotspots/waits per sampled root; attribution rows are nonadditive; read full names/args by source ID' AS evidence_scope
  FROM mtw_selected_roots r JOIN mtw_hotspots h ON h.root_slice_id = r.slice_id
  WHERE h.hotspot_rank <= 3
  UNION ALL
  SELECT 'wait', r.slice_id, r.upid, r.utid, r.track_id, NULL,
    NULL, w.state_id, w.state, w.state, w.blocked_function, w.raw_io_wait,
    printf('%d', w.overlap_start_ts), printf('%d', w.overlap_end_ts),
    printf('%d', w.overlap_end_ts - w.overlap_start_ts), NULL, NULL,
    (w.overlap_end_ts - w.overlap_start_ts) / 1e6, NULL, NULL,
    NULL, CASE WHEN w.raw_dur = -1 THEN 1 ELSE 0 END, w.wait_rank, r.task_rank,
    'top 3 hotspots/waits per sampled root; attribution rows are nonadditive; read full names/args by source ID'
  FROM mtw_selected_roots r JOIN mtw_task_waits w ON w.root_slice_id = r.slice_id
  WHERE w.wait_rank <= 3
)
SELECT * FROM main_thread_work_task_output
ORDER BY outside_doframe_ms DESC, wall_ms DESC, utid, CAST(start_ts AS INTEGER), slice_id

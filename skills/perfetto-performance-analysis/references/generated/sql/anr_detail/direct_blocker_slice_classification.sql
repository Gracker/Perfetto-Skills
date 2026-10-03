-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 74e651ef4fa4d3949dacf7c4db5b28bd3f522b40e1ff76c40cb2829ea17d44a5

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- No input CTE. ART garbage collection named by a slice or a log line.
--
-- Slices (GLOB on the original name; a consumer that has lower-cased the
-- name compares it with lower(pattern)):
--   collection  a collector run. ART names every run "<cause> <collector> GC"
--               with collector concurrent copying, concurrent mark compact,
--               (sticky or partial concurrent) mark sweep or semispace:
--               "Background young concurrent copying GC", "Alloc concurrent
--               copying GC", "Background concurrent mark compact GC".
--   wait        a thread blocked on the collector: "GC: Wait For Completion
--               <cause>", waiting for a run or for a GC critical section
--               (ProfileSaver, for one) to end. A wait overlaps what it waits
--               on, so a count or a total takes runs only and reports waits
--               as blocked time.
-- Every pattern contains "GC": a consumer scanning all slices tests
-- s.name GLOB '*GC*' first, which rejects nearly every name before the
-- pattern table is read.
-- Not GC although the name says gc: Collector classes (MetricsCollector,
-- BatchSignalCollector), art::gc::Heap::Trim* heap trimming, a gc() method
-- (SparseArray.gc), logcat, the f2fs_gc thread, and "Lock contention on GC
-- barrier lock" (a microsecond checkpoint). "Lock contention on GC thread
-- flip lock" does block a thread for the concurrent copying flip, but it is
-- lock contention, reported with locks, not counted as GC.
--
-- stdlib android_garbage_collection_events keeps depth-0 "*concurrent*GC"
-- slices that overlap a "Heap size (KB)" counter: a run nested under an app
-- thread slice (an Alloc GC on a blocked thread) or one without that counter
-- is not there, so its count can be lower than one taken with these names.
--
-- Log text (GLOB on the lower-cased text): ART reports a finished run as
-- "<cause> ... GC freed ...", a blocked thread as "WaitForGcToComplete
-- blocked ...", "Waiting for a blocking GC ..." or "Starting a blocking GC
-- ...", and a heap resize as "Clamp target GC heap ...". A bare "gc" word is
-- not enough: it is a method name, a process name or part of a path as
-- often.
art_gc_slice_name_patterns(gc_kind, pattern) AS (
  VALUES
    ('collection', '*concurrent*GC'),
    ('collection', '*mark sweep GC'),
    ('collection', '*mark compact GC'),
    ('collection', '*semispace GC'),
    ('wait', 'GC: Wait For Completion*')
),
art_gc_text_patterns(pattern) AS (
  VALUES
    ('*gc freed*'),
    ('*waitforgctocomplete*'),
    ('*waiting for a blocking gc*'),
    ('*starting a blocking gc*'),
    ('*clamp target gc heap*')
)
,
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
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} AS start_ts,
    ${anr_ts} AS end_ts,
    ${timeout_ns} AS window_ns
),
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (
      ${__process_scope.upid} IS NOT NULL
      OR (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
),
render_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (
      ${__process_scope.upid} IS NOT NULL
      OR (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.name = 'RenderThread'
  LIMIT 1
),
main_slices AS (
  SELECT
    LOWER(s.name) AS slice_name,
    MIN(CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END, aw.end_ts) - MAX(s.ts, aw.start_ts) AS clipped_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN main_thread mt ON tt.utid = mt.utid
  CROSS JOIN anr_window aw
  WHERE s.ts < aw.end_ts
    AND (CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END) > aw.start_ts
),
render_slices AS (
  SELECT
    LOWER(s.name) AS slice_name,
    MIN(CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END, aw.end_ts) - MAX(s.ts, aw.start_ts) AS clipped_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN render_thread rt ON tt.utid = rt.utid
  CROSS JOIN anr_window aw
  WHERE s.ts < aw.end_ts
    AND (CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END) > aw.start_ts
),
metrics AS (
  SELECT
    COALESCE((SELECT SUM(clipped_ns) FROM main_slices
      WHERE slice_name GLOB '*sqlite*'
        OR slice_name GLOB '*database*'
        OR slice_name GLOB '*fsync*'
        OR slice_name GLOB '*fileio*'
        OR slice_name GLOB '*file_io*'
        OR slice_name GLOB '*disk*'
        OR slice_name GLOB '*sharedpreferences*'
        OR slice_name GLOB '*queuedwork*'), 0) AS main_io_slice_ns,
    -- ART GC runs and waits on them on the main thread
    -- (fragments/art_gc_names.sql; slice_name is lower-cased). A
    -- SuspendAll in an ANR window is mostly the SIGQUIT stack dump.
    COALESCE((SELECT SUM(clipped_ns) FROM main_slices m
      WHERE EXISTS (SELECT 1 FROM art_gc_slice_name_patterns n WHERE m.slice_name GLOB lower(n.pattern))), 0) AS gc_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_slices
      WHERE slice_name GLOB '*syncanddraw*'
        OR slice_name GLOB '*waitforfence*'
        OR slice_name GLOB '*dequeuebuffer*'
        OR slice_name GLOB '*egl*'), 0) +
    COALESCE((SELECT SUM(clipped_ns) FROM render_slices
      WHERE slice_name GLOB '*syncanddraw*'
        OR slice_name GLOB '*waitforfence*'
        OR slice_name GLOB '*dequeuebuffer*'
        OR slice_name GLOB '*drawframe*'
        OR slice_name GLOB '*syncframestate*'), 0) AS render_wait_ns
),
candidates AS (
  SELECT 'db_or_file_io_slice' AS direct_blocker_type, main_io_slice_ns AS evidence_ns,
    'main_thread_slice' AS evidence_source,
    CASE WHEN main_io_slice_ns > 500000000 THEN 'medium' ELSE 'low' END AS confidence,
    'app_candidate_needs_window_context' AS root_cause_boundary,
    '需要确认该 IO slice 与 ANR 前窗口重叠，并结合系统 IO 压力判断是否被放大' AS next_evidence_needed
  FROM metrics WHERE main_io_slice_ns > 0
  UNION ALL
  SELECT 'render_or_fence_wait', render_wait_ns, 'main_or_render_thread_slice',
    CASE WHEN render_wait_ns > 500000000 THEN 'medium' ELSE 'low' END,
    'needs_render_sf_evidence',
    '需要 RenderThread、SurfaceFlinger、fence/buffer queue 证据闭环'
  FROM metrics WHERE render_wait_ns > 0
  UNION ALL
  SELECT 'gc_or_stw_wait', gc_wait_ns, 'main_thread_slice',
    CASE WHEN gc_wait_ns > 500000000 THEN 'medium' ELSE 'low' END,
    'needs_memory_gc_evidence',
    '需要 GC/logcat、PSI memory、LMK/OOM 或多线程暂停证据确认'
  FROM metrics WHERE gc_wait_ns > 0
)
SELECT
  direct_blocker_type,
  ROUND(evidence_ns / 1e6, 2) AS evidence_ms,
  ROUND(100.0 * evidence_ns / NULLIF((SELECT window_ns FROM anr_window), 0), 1) AS pct_of_timeout,
  evidence_source,
  confidence,
  root_cause_boundary,
  next_evidence_needed
FROM candidates
ORDER BY
  CASE confidence WHEN 'medium' THEN 1 ELSE 2 END,
  evidence_ns DESC
LIMIT 5

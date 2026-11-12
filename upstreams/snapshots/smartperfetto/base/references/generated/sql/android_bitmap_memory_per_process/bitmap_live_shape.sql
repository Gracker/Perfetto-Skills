-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: 0b50760adf1ce6444677ccef1d5b8511489b81f17a4007ec9e3efff6c919964b

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Process scope shared by the heap graph, heapprofd and Bitmap Skills.
-- Candidates are processes that have heap data (a heap graph dump or heapprofd
-- allocations) or Bitmap memory counters (atrace "view"), so a trace with only
-- Bitmap counters still has candidates. Consumers join their own data to
-- heap_target_process, so a candidate without that data adds no rows.
-- Rule, in order:
--   1. An explicit upid selects exactly that process.
--   2. process_name (or package) matches a process name exactly or as its
--      `name:*` subprocess. There is no substring matching, so `com.foo` never
--      selects `com.foobar`.
--   3. When a name was given and no candidate matches, heap graph/heapprofd
--      candidates without a process name are used instead (an .hprof dump has
--      none) and flagged process_name_unavailable_upid_fallback; they are never
--      silently dropped. A Bitmap-counter-only process never takes this
--      fallback, but a name matching it does count as a match.
--   4. With no upid and no name every candidate is in scope.
heap_target_input AS (
  SELECT
    ${upid} AS target_upid,
    COALESCE(NULLIF('${process_name|}', ''), NULLIF('${package|}', ''), '') AS target_name
),
heap_data_processes AS (
  SELECT upid, MAX(has_heap_dump) AS has_heap_dump
  FROM (
    SELECT upid, 1 AS has_heap_dump FROM heap_graph
    UNION ALL
    SELECT DISTINCT upid, 1 AS has_heap_dump FROM heap_profile_allocation
    UNION ALL
    SELECT upid, 0 AS has_heap_dump FROM process_counter_track
    WHERE name IN ('Bitmap Memory', 'Bitmap Count')
  )
  GROUP BY upid
),
heap_target_name_matches AS (
  SELECT d.upid
  FROM heap_data_processes AS d
  JOIN process AS p USING (upid)
  CROSS JOIN heap_target_input AS i
  WHERE i.target_name != ''
    AND (p.name = i.target_name OR p.name GLOB i.target_name || ':*')
),
heap_target_process AS (
  SELECT
    d.upid,
    COALESCE(p.name, printf('upid:%d', d.upid)) AS process_name,
    CASE
      WHEN i.target_upid IS NOT NULL THEN 'upid_selected'
      WHEN i.target_name = '' THEN 'all_heap_processes'
      WHEN m.upid IS NOT NULL THEN 'process_name_match'
      ELSE 'process_name_unavailable_upid_fallback'
    END AS process_identity
  FROM heap_data_processes AS d
  CROSS JOIN heap_target_input AS i
  LEFT JOIN process AS p USING (upid)
  LEFT JOIN heap_target_name_matches AS m USING (upid)
  WHERE (i.target_upid IS NOT NULL AND d.upid = i.target_upid)
    OR (i.target_upid IS NULL AND (
      i.target_name = ''
      OR m.upid IS NOT NULL
      OR (p.name IS NULL AND d.has_heap_dump AND NOT EXISTS (SELECT 1 FROM heap_target_name_matches))
    ))
)
,
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
input AS (
  SELECT
    COALESCE(${bitmap_growth_min_mb|32}, 32) AS bitmap_growth_min_mb,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
),
mem AS (
  SELECT
    m.upid,
    m.ts,
    m.value,
    ROW_NUMBER() OVER (PARTITION BY m.upid ORDER BY m.ts ASC) AS rn_first,
    ROW_NUMBER() OVER (PARTITION BY m.upid ORDER BY m.ts DESC) AS rn_last,
    m.value - LAG(m.value) OVER (PARTITION BY m.upid ORDER BY m.ts ASC) AS delta
  FROM android_bitmap_memory m
  JOIN heap_target_process USING (upid)
  CROSS JOIN input
  WHERE m.ts >= input.start_ts
    AND m.ts < input.end_ts
),
counts AS (
  SELECT
    upid,
    MAX(CASE WHEN rn_first = 1 THEN value END) AS first_count,
    MAX(CASE WHEN rn_last = 1 THEN value END) AS last_count
  FROM (
    SELECT
      c.upid,
      c.value,
      ROW_NUMBER() OVER (PARTITION BY c.upid ORDER BY c.ts ASC) AS rn_first,
      ROW_NUMBER() OVER (PARTITION BY c.upid ORDER BY c.ts DESC) AS rn_last
    FROM android_bitmap_count c
    JOIN heap_target_process USING (upid)
    CROSS JOIN input
    WHERE c.ts >= input.start_ts
      AND c.ts < input.end_ts
  )
  GROUP BY upid
),
shapes AS (
  SELECT
    upid,
    COUNT(*) AS samples,
    MIN(ts) AS first_ts,
    MAX(ts) AS last_ts,
    (MAX(CASE WHEN rn_last = 1 THEN value END) - MAX(CASE WHEN rn_first = 1 THEN value END)) / 1048576.0
      AS net_growth_mb,
    MAX(CASE WHEN rn_first = 1 THEN value END) AS first_bytes,
    MAX(CASE WHEN rn_last = 1 THEN value END) AS last_bytes,
    SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) AS rise_steps,
    SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) AS drop_steps,
    COALESCE(-MIN(CASE WHEN delta < 0 THEN delta END), 0) AS max_single_drop_bytes
  FROM mem
  GROUP BY upid
),
gc_runs AS (
  SELECT t.upid, gc_slice.ts
  FROM slice gc_slice
  JOIN thread_track tt ON gc_slice.track_id = tt.id
  JOIN thread t USING (utid)
  WHERE gc_slice.name GLOB '*GC*'
    AND t.upid IN (SELECT upid FROM shapes)
    AND EXISTS (
      SELECT 1 FROM art_gc_slice_name_patterns n
      WHERE n.gc_kind = 'collection' AND gc_slice.name GLOB n.pattern
    )
),
gcs AS (
  SELECT sh.upid, COUNT(g.ts) AS gcs_in_span
  FROM shapes sh
  LEFT JOIN gc_runs g
    ON g.upid = sh.upid
    AND g.ts >= sh.first_ts
    AND g.ts <= sh.last_ts
  GROUP BY sh.upid
)
SELECT
  t.process_name,
  s.upid,
  s.samples,
  ROUND((s.last_ts - s.first_ts) / 1e9, 2) AS span_s,
  ROUND(s.first_bytes / 1048576.0, 2) AS first_mb,
  ROUND(s.last_bytes / 1048576.0, 2) AS last_mb,
  ROUND(s.net_growth_mb, 2) AS net_growth_mb,
  s.rise_steps,
  s.drop_steps,
  ROUND(s.max_single_drop_bytes / 1048576.0, 2) AS max_single_drop_mb,
  c.first_count,
  c.last_count,
  g.gcs_in_span,
  CASE
    WHEN s.net_growth_mb < input.bitmap_growth_min_mb THEN 'below_growth_threshold'
    WHEN s.drop_steps = 0 AND g.gcs_in_span > 0 THEN 'retained_growth_across_gc'
    WHEN s.drop_steps = 0 THEN 'retained_growth_no_gc_in_span'
    ELSE 'growth_with_release'
  END AS shape,
  t.process_identity
FROM shapes s
JOIN heap_target_process t USING (upid)
CROSS JOIN input
LEFT JOIN counts c USING (upid)
LEFT JOIN gcs g USING (upid)
WHERE s.samples >= 2
ORDER BY s.net_growth_mb DESC
LIMIT 50

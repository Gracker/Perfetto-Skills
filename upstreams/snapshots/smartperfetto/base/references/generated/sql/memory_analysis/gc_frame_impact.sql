-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: 1fb350c1d3eb4af09e605373da275721d9521ff7f20b34a245513f545b5b6dd1

-- One row per main-thread GC, over the frames of the process that ran
-- it; a frame of another process at the same time says nothing about it.
-- A process with no FrameTimeline cannot show a frame impact either way.
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

-- Input: fragments/art_gc_names.sql, listed before this fragment; the step
-- parameters package, start_ts and end_ts. The GC slices of the target
-- process(es) that start in the range, one row per slice: runs and waits,
-- told apart by gc_kind. gc_type is the cause ART names a run by (Explicit,
-- Alloc), Young for another young-generation run, Background for another
-- background run, or Wait for a thread blocked on the collector.
memory_gc_events AS (
  SELECT
    *,
    CASE
      WHEN gc_kind = 'wait' THEN 'Wait'
      WHEN gc_name GLOB '*Explicit*' THEN 'Explicit'
      WHEN gc_name GLOB 'Alloc*' OR gc_name GLOB 'NativeAlloc*' THEN 'Alloc'
      WHEN gc_name GLOB '*young*' THEN 'Young'
      WHEN gc_name GLOB 'Background*' THEN 'Background'
      ELSE 'Other'
    END AS gc_type
  FROM (
    SELECT
      s.id AS gc_id,
      s.ts,
      s.dur,
      s.name AS gc_name,
      (
        SELECT n.gc_kind FROM art_gc_slice_name_patterns n
        WHERE s.name GLOB n.pattern
        ORDER BY n.gc_kind
        LIMIT 1
      ) AS gc_kind,
      t.name AS thread_name,
      t.tid,
      p.pid,
      p.upid,
      CASE WHEN t.tid = p.pid THEN 1 ELSE 0 END AS is_main_thread
    FROM slice s
    JOIN thread_track tt ON s.track_id = tt.id
    JOIN thread t ON tt.utid = t.utid
    JOIN process p ON t.upid = p.upid
    WHERE s.name GLOB '*GC*'
      AND ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
      AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
      AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  )
  WHERE gc_kind IS NOT NULL
)
,
gc_frames AS (
  SELECT
    gc.gc_id, gc.ts, gc.upid, gc.gc_name, gc.dur,
    af.id AS frame_id, af.dur AS frame_dur, af.jank_type
  FROM memory_gc_events gc
  LEFT JOIN actual_frame_timeline_slice af ON (
    af.upid = gc.upid AND af.ts < gc.ts + gc.dur AND af.ts + af.dur > gc.ts
  )
  WHERE gc.is_main_thread = 1
)
SELECT
  gc_name,
  dur / 1e6 AS gc_dur_ms,
  COUNT(frame_id) AS frame_count,
  COALESCE(SUM(jank_type != 'None'), 0) AS janky_frame_count,
  group_concat(DISTINCT CASE WHEN jank_type != 'None' THEN jank_type END) AS jank_type,
  MAX(frame_dur) / 1e6 AS frame_dur_ms,
  CASE
    WHEN NOT EXISTS (SELECT 1 FROM actual_frame_timeline_slice f WHERE f.upid = gc_frames.upid) THEN '无帧时间线数据'
    WHEN COUNT(frame_id) = 0 THEN '无重叠帧'
    WHEN SUM(jank_type != 'None') > 0 THEN 'GC导致掉帧'
    WHEN MAX(frame_dur) > ${vsync_info.data[0].vsync_period_ns|16666667} THEN '帧超时'
    ELSE '正常'
  END AS impact
FROM gc_frames
GROUP BY gc_id
ORDER BY dur DESC, ts, gc_id
LIMIT 30

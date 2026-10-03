-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/logcat_analysis.skill.yaml
-- Source SHA-256: 4c006bf2fd2861d2f647a5ad1a5b282ebec951cf2ec824f792431262fb8769cb

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
tagged AS (
  SELECT
    ts,
    prio,
    tag,
    msg,
    CASE
      WHEN LOWER(COALESCE(tag, '')) GLOB '*inputdispatcher*'
        OR LOWER(COALESCE(msg, '')) GLOB '*input dispatching timed out*'
        THEN 'input_dispatch'
      WHEN LOWER(COALESCE(msg, '')) GLOB '*no focused window*'
        OR LOWER(COALESCE(msg, '')) GLOB '*does not have a focused window*'
        THEN 'no_focus_window'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*anrmanager*'
        OR LOWER(COALESCE(msg, '')) GLOB '*anr in *'
        THEN 'anrmanager'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*activitymanager*'
        OR LOWER(COALESCE(tag, '')) GLOB '*activitytaskmanager*'
        THEN 'activity_manager'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*windowmanager*'
        THEN 'window_manager'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*broadcastqueue*'
        OR LOWER(COALESCE(msg, '')) GLOB '*broadcast of intent*'
        THEN 'broadcast_timeout'
      WHEN LOWER(COALESCE(msg, '')) GLOB '*executing service*'
        OR LOWER(COALESCE(msg, '')) GLOB '*start foreground service*'
        OR LOWER(COALESCE(tag, '')) GLOB '*activeservices*'
        THEN 'service_timeout'
      WHEN LOWER(COALESCE(msg, '')) GLOB '*contentprovider not responding*'
        OR LOWER(COALESCE(msg, '')) GLOB '*content provider not responding*'
        THEN 'provider_timeout'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*jobscheduler*'
        OR LOWER(COALESCE(msg, '')) GLOB '*jobservice*'
        THEN 'job_scheduler'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*watchdog*'
        OR LOWER(COALESCE(msg, '')) GLOB '*watchdog*'
        THEN 'watchdog'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*lmkd*'
        OR LOWER(COALESCE(tag, '')) GLOB '*lowmemorykiller*'
        OR LOWER(COALESCE(msg, '')) GLOB '*low memory*'
        OR LOWER(COALESCE(msg, '')) GLOB '*pressure*'
        THEN 'memory_pressure'
      -- The ART runtime logs under tag "art"; its GC lines are named in
      -- fragments/art_gc_names.sql ("start" and "logcat" are neither).
      WHEN LOWER(COALESCE(tag, '')) = 'art'
        OR EXISTS (SELECT 1 FROM art_gc_text_patterns g WHERE LOWER(COALESCE(msg, '')) GLOB g.pattern)
        THEN 'gc_or_art'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*choreographer*'
        OR LOWER(COALESCE(tag, '')) GLOB '*surfaceflinger*'
        OR LOWER(COALESCE(msg, '')) GLOB '*skipped frames*'
        THEN 'render_or_frame'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*strictmode*'
        OR LOWER(COALESCE(tag, '')) GLOB '*binder*'
        OR LOWER(COALESCE(msg, '')) GLOB '*anr*'
        OR LOWER(COALESCE(msg, '')) GLOB '*not responding*'
        THEN 'anr_related'
      ELSE 'other'
    END AS signal_type
  FROM android_logs
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
scoped AS (
  SELECT
    tagged.*,
    CASE
      WHEN '${package|}' <> ''
        AND (
          instr(LOWER(COALESCE(msg, '')), LOWER('${package|}')) > 0
          OR instr(LOWER(COALESCE(tag, '')), LOWER('${package|}')) > 0
        )
        THEN 1 ELSE 0
    END AS package_match
  FROM tagged
)
SELECT
  printf('%d', ts) as ts_str,
  CASE prio
    WHEN 4 THEN 'INFO'
    WHEN 5 THEN 'WARN'
    WHEN 6 THEN 'ERROR'
    WHEN 7 THEN 'FATAL'
    ELSE 'INFO'
  END as prio,
  tag,
  signal_type,
  CASE
    WHEN '${package|}' = '' THEN 'global'
    WHEN package_match = 1 THEN 'target_scoped'
    ELSE 'global_context'
  END AS evidence_scope,
  SUBSTR(msg, 1, 200) as msg_preview
FROM scoped
WHERE (prio >= 5 OR (prio >= 4 AND signal_type <> 'other'))
  AND (
    '${package|}' = ''
    OR package_match = 1
    OR (prio >= 5 AND signal_type <> 'other')
  )
ORDER BY ts
LIMIT 50

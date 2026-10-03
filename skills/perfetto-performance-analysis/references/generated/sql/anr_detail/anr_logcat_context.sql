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
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} AS start_ts,
    ${anr_ts} AS anr_ts,
    ${anr_ts} + 5000000000 AS end_ts
),
tagged AS (
  SELECT
    l.*,
    CASE
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*inputdispatcher*' OR LOWER(COALESCE(l.msg, '')) GLOB '*input dispatch*' THEN 'input_dispatch'
      WHEN LOWER(COALESCE(l.msg, '')) GLOB '*no focused window*' OR LOWER(COALESCE(l.msg, '')) GLOB '*no focus window*' THEN 'no_focus_window'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*anrmanager*' THEN 'anrmanager'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*activitymanager*' OR LOWER(COALESCE(l.tag, '')) GLOB '*activitytaskmanager*' THEN 'activity_manager'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*windowmanager*' THEN 'window_manager'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*broadcastqueue*' OR LOWER(COALESCE(l.msg, '')) GLOB '*broadcast*timeout*' THEN 'broadcast_timeout'
      WHEN LOWER(COALESCE(l.msg, '')) GLOB '*executing service*' OR LOWER(COALESCE(l.msg, '')) GLOB '*foreground service*' THEN 'service_timeout'
      WHEN LOWER(COALESCE(l.msg, '')) GLOB '*contentprovider*' OR LOWER(COALESCE(l.msg, '')) GLOB '*provider not responding*' THEN 'provider_timeout'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*jobscheduler*' OR LOWER(COALESCE(l.msg, '')) GLOB '*jobservice*' THEN 'job_scheduler'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*watchdog*' OR LOWER(COALESCE(l.msg, '')) GLOB '*system_server*watchdog*' THEN 'watchdog'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*lmkd*' OR LOWER(COALESCE(l.tag, '')) GLOB '*lowmemorykiller*' OR LOWER(COALESCE(l.msg, '')) GLOB '*lowmemory*' THEN 'memory_pressure'
      -- ART logs under tag "art"; its GC lines: fragments/art_gc_names.sql.
      WHEN LOWER(COALESCE(l.tag, '')) = 'art'
        OR EXISTS (SELECT 1 FROM art_gc_text_patterns g WHERE LOWER(COALESCE(l.msg, '')) GLOB g.pattern) THEN 'gc_or_art'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*strictmode*'
        OR LOWER(COALESCE(l.tag, '')) GLOB '*binder*'
        OR LOWER(COALESCE(l.msg, '')) GLOB '*anr*'
        OR LOWER(COALESCE(l.msg, '')) GLOB '*not responding*'
        THEN 'anr_related'
      ELSE 'other'
    END AS signal_type
  FROM android_logs l
),
scoped AS (
  SELECT
    l.*,
    CASE
      WHEN '${process_name}' <> ''
        AND instr(LOWER(COALESCE(l.msg, '')), LOWER('${process_name}')) > 0
        THEN 1 ELSE 0
    END AS process_match,
    CASE
      WHEN '${component}' <> ''
        AND instr(LOWER(COALESCE(l.msg, '')), LOWER('${component}')) > 0
        THEN 1 ELSE 0
    END AS component_match,
    CASE
      WHEN '${intent}' <> ''
        AND instr(LOWER(COALESCE(l.msg, '')), LOWER('${intent}')) > 0
        THEN 1 ELSE 0
    END AS intent_match,
    CASE
      WHEN '${error_id}' <> ''
        AND instr(LOWER(COALESCE(l.msg, '')), LOWER('${error_id}')) > 0
        THEN 1 ELSE 0
    END AS error_match,
    CASE
      WHEN l.signal_type IN (
        'input_dispatch',
        'no_focus_window',
        'anrmanager',
        'activity_manager',
        'window_manager',
        'broadcast_timeout',
        'service_timeout',
        'provider_timeout',
        'job_scheduler',
        'watchdog',
        'memory_pressure',
        'gc_or_art',
        'anr_related'
      ) THEN 1 ELSE 0
    END AS global_signal_match
  FROM tagged l
)
SELECT
  '${error_id}' AS error_id,
  ROUND((l.ts - aw.anr_ts) / 1e6, 2) AS relation_to_anr_ms,
  CASE
    WHEN l.ts < aw.anr_ts THEN 'pre_anr'
    WHEN l.ts <= aw.anr_ts + 1000000000 THEN 'dump_or_trigger'
    ELSE 'post_anr'
  END AS phase,
  CASE
    WHEN l.ts <= aw.anr_ts
      AND (l.error_match = 1 OR l.component_match = 1 OR l.intent_match = 1)
      AND (
        l.global_signal_match = 1
        OR (l.prio >= 5 AND l.signal_type <> 'other')
      )
      THEN 1
    ELSE 0
  END AS root_cause_eligible,
  l.signal_type,
  CASE
    WHEN l.error_match = 1 OR l.component_match = 1 OR l.intent_match = 1 THEN 'event_scoped'
    WHEN l.process_match = 1 THEN 'target_process_context'
    ELSE 'global_context'
  END AS evidence_scope,
  CASE l.prio
    WHEN 4 THEN 'INFO'
    WHEN 5 THEN 'WARN'
    WHEN 6 THEN 'ERROR'
    WHEN 7 THEN 'FATAL'
    ELSE CAST(l.prio AS TEXT)
  END AS prio,
  l.tag,
  SUBSTR(l.msg, 1, 220) AS msg_preview
FROM scoped l
CROSS JOIN anr_window aw
WHERE l.ts >= aw.start_ts
  AND l.ts <= aw.end_ts
  AND l.prio >= 4
  AND (
    l.process_match = 1
    OR l.component_match = 1
    OR l.intent_match = 1
    OR l.error_match = 1
    OR (
      l.ts <= aw.anr_ts
      AND l.global_signal_match = 1
    )
  )
ORDER BY root_cause_eligible DESC, ABS(l.ts - aw.anr_ts), l.ts
LIMIT 40

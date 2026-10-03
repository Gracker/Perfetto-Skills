-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 1fa589ef5136298372b33fb125b7e0ffa15108e83ecabe89690df65f9bf71ed2

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

-- No input CTE; the step parameters process_name, package and anr_type (each
-- '' for any). The ANRs of android_anrs that match them, every column kept,
-- plus the window an analysis looks back over:
--   analysis_timeout_ms  the ANR's own duration, else Perfetto's default for
--                        its type, else the platform timeout of the type
--   timeout_source       actual_anr_duration | perfetto_default |
--                        heuristic_fallback, saying which one it is
anr_matched AS (
  SELECT
    *,
    COALESCE(
      NULLIF(anr_dur_ms, 0),
      default_anr_dur_ms,
      CASE
        WHEN anr_type IN ('INPUT_DISPATCHING_TIMEOUT', 'INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW') THEN 5000
        WHEN anr_type = 'BROADCAST_OF_INTENT' THEN 10000
        WHEN anr_type = 'EXECUTING_SERVICE' THEN 20000
        WHEN anr_type IN ('START_FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_TIMEOUT') THEN 30000
        WHEN anr_type = 'FOREGROUND_SHORT_SERVICE_TIMEOUT' THEN 180000
        WHEN anr_type IN ('JOB_SERVICE_START', 'JOB_SERVICE_STOP', 'JOB_SERVICE_BIND', 'JOB_SERVICE_NOTIFICATION_NOT_PROVIDED') THEN 8000
        WHEN anr_type = 'BIND_APPLICATION' THEN 15000
        -- Perfetto's default is NULL for the remaining types: an explicit
        -- low-confidence lookback so downstream SQL still has bounds.
        ELSE 5000
      END
    ) AS analysis_timeout_ms,
    CASE
      WHEN NULLIF(anr_dur_ms, 0) IS NOT NULL THEN 'actual_anr_duration'
      WHEN default_anr_dur_ms IS NOT NULL THEN 'perfetto_default'
      ELSE 'heuristic_fallback'
    END AS timeout_source
  FROM android_anrs
  WHERE (
      ('${process_name}' <> '' AND (process_name = '${process_name}' OR process_name GLOB '${process_name}:*'))
      OR ('${package}' <> '' AND (process_name = '${package}' OR process_name GLOB '${package}:*'))
      OR ('${process_name}' = '' AND '${package}' = '')
    )
    AND (anr_type = '${anr_type}' OR '${anr_type}' = '')
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: fragments/art_gc_names.sql and fragments/anr_matched.sql, listed
-- before this fragment. The matched ANRs, every column kept, plus:
--   trigger_type              the trigger family of anr_type
--   root_cause_pattern_hint   comma-separated candidate patterns named by the
--                             subject text ('' when none): a starting point for
--                             the investigation, never its conclusion
anr_classified AS (
  SELECT
    *,
    CASE
      WHEN anr_type = 'INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW' THEN 'no_focus_window'
      WHEN anr_type = 'INPUT_DISPATCHING_TIMEOUT' THEN 'input_dispatching_timeout'
      WHEN anr_type = 'BROADCAST_OF_INTENT' THEN 'broadcast_timeout'
      WHEN anr_type IN ('EXECUTING_SERVICE', 'START_FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_TIMEOUT', 'FOREGROUND_SHORT_SERVICE_TIMEOUT') THEN 'service_timeout'
      WHEN anr_type = 'CONTENT_PROVIDER_NOT_RESPONDING' THEN 'content_provider_timeout'
      WHEN anr_type IN ('JOB_SERVICE_START', 'JOB_SERVICE_STOP', 'JOB_SERVICE_BIND', 'JOB_SERVICE_NOTIFICATION_NOT_PROVIDED') THEN 'job_scheduler_timeout'
      WHEN anr_type = 'SYSTEM_SERVER_WATCHDOG_TIMEOUT' THEN 'system_watchdog_swt'
      WHEN anr_type = 'BIND_APPLICATION' THEN 'bind_application_timeout'
      WHEN anr_type = 'GPU_HANG' THEN 'gpu_hang'
      WHEN anr_type = 'APP_TRIGGERED' THEN 'app_triggered_anr'
      ELSE 'unknown'
    END AS trigger_type,
    TRIM(
      (CASE
        WHEN LOWER(COALESCE(subject, '')) GLOB '*deadlock*'
          OR LOWER(COALESCE(subject, '')) GLOB '*waiting to lock*'
          OR LOWER(COALESCE(subject, '')) GLOB '*monitor contention*'
          OR LOWER(COALESCE(subject, '')) GLOB '*futex*'
          THEN 'deadlock,' ELSE '' END) ||
      (CASE
        WHEN LOWER(COALESCE(subject, '')) GLOB '*oom*'
          OR LOWER(COALESCE(subject, '')) GLOB '*lmk*'
          OR LOWER(COALESCE(subject, '')) GLOB '*memory*'
          OR EXISTS (SELECT 1 FROM art_gc_text_patterns g WHERE LOWER(COALESCE(subject, '')) GLOB g.pattern)
          THEN 'memory_leak_oom_pressure,' ELSE '' END) ||
      (CASE
        WHEN LOWER(COALESCE(subject, '')) GLOB '*cpu*'
          OR LOWER(COALESCE(subject, '')) GLOB '*iowait*'
          OR LOWER(COALESCE(subject, '')) GLOB '*load*'
          OR LOWER(COALESCE(subject, '')) GLOB '*sched*'
          THEN 'high_load_anr,' ELSE '' END),
      ','
    ) AS root_cause_pattern_hint
  FROM anr_matched
)
,
classified AS (
  SELECT
    anr_type AS source_anr_type,
    trigger_type,
    CASE WHEN anr_type = 'UNKNOWN_ANR_TYPE' OR anr_type IS NULL THEN 'low' ELSE 'high' END AS type_confidence,
    root_cause_pattern_hint
  FROM anr_classified
)
SELECT
  source_anr_type,
  trigger_type,
  COUNT(*) AS event_count,
  MIN(type_confidence) AS type_confidence,
  COALESCE(NULLIF(GROUP_CONCAT(DISTINCT NULLIF(root_cause_pattern_hint, '')), ''), 'none') AS root_cause_pattern_hints,
  1 AS not_final,
  CASE trigger_type
    WHEN 'input_dispatching_timeout' THEN '主线程是否 5s 内未处理输入；重点看 direct blocker、Binder/锁/IO/调度压力'
    WHEN 'no_focus_window' THEN '按 resume → relayout → draw/focus 三步检查窗口焦点链，主线程 nativePoll 不单独定因'
    WHEN 'broadcast_timeout' THEN '检查 onReceive/goAsync/finish 与工作线程，区分前台 10s 和后台 60s'
    WHEN 'service_timeout' THEN '检查 Service 生命周期、前台服务启动和冷启动链路'
    WHEN 'content_provider_timeout' THEN '区分 provider publish 与 query/CRUD not responding；看 provider main 或 Binder 线程'
    WHEN 'job_scheduler_timeout' THEN '检查 JobService onStartJob/onStopJob/bind 与 JobScheduler 调度链路'
    WHEN 'system_watchdog_swt' THEN 'system_server Watchdog/SWT，优先系统服务 Handler/锁/Binder 线程'
    WHEN 'gpu_hang' THEN 'GPU/fence/buffer 方向候选，必须和 RenderThread/SF 证据闭环'
    ELSE '未知/厂商扩展 ANR，保留 baseline evidence，先确认触发类型'
  END AS analysis_focus
FROM classified
GROUP BY source_anr_type, trigger_type
ORDER BY event_count DESC

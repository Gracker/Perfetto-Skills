-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 7ff32bd00930745e7472e3fd492581136074cf0cf6843caf8fecf18d85f1a757

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
normalized AS (
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
        WHEN anr_type IN ('CONTENT_PROVIDER_NOT_RESPONDING', 'GPU_HANG', 'APP_TRIGGERED', 'UNKNOWN_ANR_TYPE') THEN 5000
        ELSE 5000
      END
    ) AS analysis_timeout_ms,
    CASE
      WHEN NULLIF(anr_dur_ms, 0) IS NOT NULL THEN 'actual_anr_duration'
      WHEN default_anr_dur_ms IS NOT NULL THEN 'perfetto_default'
      ELSE 'heuristic_fallback'
    END AS timeout_source,
    COALESCE(NULLIF(TRIM(
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
    ), ''), 'none') AS root_cause_pattern_hints
  FROM android_anrs
  WHERE (
      ('${process_name}' <> '' AND (process_name = '${process_name}' OR process_name GLOB '${process_name}:*'))
      OR ('${package}' <> '' AND (process_name = '${package}' OR process_name GLOB '${package}:*'))
      OR ('${process_name}' = '' AND '${package}' = '')
    )
    AND (anr_type = '${anr_type}' OR '${anr_type}' = '')
)
SELECT
  error_id,
  process_name,
  pid,
  upid,
  anr_type,
  trigger_type,
  ROUND(anr_dur_ms, 2) as anr_dur_ms,
  ROUND(analysis_timeout_ms, 2) as timeout_ms,
  printf('%d', ts) as anr_ts,
  printf('%d', CAST(analysis_timeout_ms * 1e6 AS INTEGER)) as timeout_ns,
  intent,
  component,
  SUBSTR(subject, 1, 150) AS subject_preview,
  printf('%d', CAST(ts - analysis_timeout_ms * 1e6 AS INTEGER)) as perfetto_start,
  printf('%d', ts) as perfetto_end,
  CASE anr_type
    WHEN 'INPUT_DISPATCHING_TIMEOUT' THEN '输入超时'
    WHEN 'INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW' THEN '无焦点窗口输入超时'
    WHEN 'BROADCAST_OF_INTENT' THEN '广播超时'
    WHEN 'START_FOREGROUND_SERVICE' THEN '前台服务启动超时'
    WHEN 'EXECUTING_SERVICE' THEN '服务超时'
    WHEN 'CONTENT_PROVIDER_NOT_RESPONDING' THEN 'CP超时'
    WHEN 'JOB_SERVICE_START' THEN 'JobService start 超时'
    WHEN 'JOB_SERVICE_STOP' THEN 'JobService stop 超时'
    WHEN 'JOB_SERVICE_BIND' THEN 'JobService bind 超时'
    WHEN 'SYSTEM_SERVER_WATCHDOG_TIMEOUT' THEN 'system_server Watchdog'
    WHEN 'GPU_HANG' THEN 'GPU Hang'
    ELSE anr_type
  END as type_display,
  timeout_source,
  CASE trigger_type
    WHEN 'input_dispatching_timeout' THEN '主线程 direct blocker、Binder/锁/IO/调度压力'
    WHEN 'no_focus_window' THEN 'resume → relayout → draw/focus 链'
    WHEN 'broadcast_timeout' THEN 'onReceive/goAsync/finish 与工作线程'
    WHEN 'service_timeout' THEN 'Service 生命周期和前台服务启动'
    WHEN 'content_provider_timeout' THEN 'provider publish/query 与 Binder 线程'
    WHEN 'job_scheduler_timeout' THEN 'JobService 回调和 JobScheduler bind/start'
    WHEN 'system_watchdog_swt' THEN 'system_server Watchdog/SWT 系统服务线程'
    WHEN 'gpu_hang' THEN 'RenderThread/SF/fence 旁证'
    ELSE '确认触发类型后再定根因边界'
  END AS analysis_focus,
  root_cause_pattern_hints
FROM normalized
ORDER BY ts ASC

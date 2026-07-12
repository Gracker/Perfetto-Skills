-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH normalized AS (
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
          OR LOWER(COALESCE(subject, '')) GLOB '*gc*'
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

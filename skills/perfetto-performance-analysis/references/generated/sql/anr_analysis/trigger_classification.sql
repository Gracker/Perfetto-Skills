-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH classified AS (
  SELECT
    anr_type AS source_anr_type,
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
    CASE
      WHEN anr_type = 'UNKNOWN_ANR_TYPE' THEN 'low'
      WHEN anr_type IS NULL THEN 'low'
      ELSE 'high'
    END AS type_confidence,
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
          OR LOWER(COALESCE(subject, '')) GLOB '*gc*'
          THEN 'memory_leak_oom_pressure,' ELSE '' END) ||
      (CASE
        WHEN LOWER(COALESCE(subject, '')) GLOB '*cpu*'
          OR LOWER(COALESCE(subject, '')) GLOB '*iowait*'
          OR LOWER(COALESCE(subject, '')) GLOB '*load*'
          OR LOWER(COALESCE(subject, '')) GLOB '*sched*'
          THEN 'high_load_anr,' ELSE '' END),
      ','
    ) AS root_cause_pattern_hint
  FROM android_anrs
  WHERE (
      ('${process_name}' <> '' AND (process_name = '${process_name}' OR process_name GLOB '${process_name}:*'))
      OR ('${package}' <> '' AND (process_name = '${package}' OR process_name GLOB '${package}:*'))
      OR ('${process_name}' = '' AND '${package}' = '')
    )
    AND (anr_type = '${anr_type}' OR '${anr_type}' = '')
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

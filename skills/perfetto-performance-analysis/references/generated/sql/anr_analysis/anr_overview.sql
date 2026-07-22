-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH classified AS (
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
  anr_type,
  trigger_type,
  COUNT(*) AS anr_count,
  GROUP_CONCAT(DISTINCT process_name) AS affected_processes,
  ROUND(AVG(anr_dur_ms), 2) AS avg_anr_dur_ms,
  ROUND(AVG(default_anr_dur_ms), 2) AS default_timeout_ms,
  CASE anr_type
    WHEN 'INPUT_DISPATCHING_TIMEOUT' THEN '输入超时 (5s无响应)'
    WHEN 'INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW' THEN '无焦点窗口输入超时 (5s)'
    WHEN 'BROADCAST_OF_INTENT' THEN '广播超时 (前台10s/后台60s)'
    WHEN 'START_FOREGROUND_SERVICE' THEN '前台服务启动超时'
    WHEN 'EXECUTING_SERVICE' THEN '服务执行超时 (前台20s/后台200s)'
    WHEN 'CONTENT_PROVIDER_NOT_RESPONDING' THEN 'ContentProvider 超时'
    WHEN 'JOB_SERVICE_START' THEN 'JobService onStartJob 超时'
    WHEN 'JOB_SERVICE_STOP' THEN 'JobService onStopJob 超时'
    WHEN 'JOB_SERVICE_BIND' THEN 'JobService bind 超时'
    WHEN 'SYSTEM_SERVER_WATCHDOG_TIMEOUT' THEN 'system_server Watchdog 超时'
    WHEN 'GPU_HANG' THEN 'GPU Hang'
    ELSE anr_type
  END as type_display,
  CASE trigger_type
    WHEN 'input_dispatching_timeout' THEN '检查主线程 direct blocker、Binder/锁/IO/调度压力'
    WHEN 'no_focus_window' THEN '检查 resume/relayout/draw/focus 链，不把 nativePoll 单独定因'
    WHEN 'broadcast_timeout' THEN '检查 BroadcastReceiver.onReceive()/goAsync()/finish()'
    WHEN 'service_timeout' THEN '检查 Service 生命周期方法、前台服务启动和冷启动链'
    WHEN 'content_provider_timeout' THEN '区分 provider publish 与 query/CRUD not responding'
    WHEN 'job_scheduler_timeout' THEN '检查 JobService 回调和 JobScheduler bind/start 链'
    WHEN 'system_watchdog_swt' THEN '按 system_server Watchdog/SWT 排查系统服务线程'
    WHEN 'gpu_hang' THEN '检查 GPU/fence/buffer 与 RenderThread/SF 旁证'
    ELSE '先确认触发类型，再检查主线程阻塞原因'
  END as quick_hint,
  COALESCE(NULLIF(GROUP_CONCAT(DISTINCT NULLIF(root_cause_pattern_hint, '')), ''), 'none') AS root_cause_pattern_hints,
  1 AS not_final
FROM classified
GROUP BY anr_type, trigger_type
ORDER BY anr_count DESC

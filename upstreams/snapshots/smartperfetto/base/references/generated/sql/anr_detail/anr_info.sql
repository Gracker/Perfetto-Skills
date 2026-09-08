-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 283e74c341c76d3959624287f046bcc7f85e2b7b1cbe1edfab07c544a01660af
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  COALESCE((SELECT name FROM process WHERE upid = ${__process_scope.upid}), '${process_name}') as process_name,
  (SELECT pid FROM process WHERE upid = ${__process_scope.upid}) as pid,
  ${__process_scope.upid} as upid,
  '${anr_type}' as anr_type,
  '${error_id}' as error_id,
  ROUND(COALESCE(${anr_dur_ms}, 0), 2) as anr_dur_ms,
  ROUND(${timeout_ns} / 1e6, 2) as timeout_ms,
  printf('%d', ${anr_ts}) as anr_ts,
  printf('%d', COALESCE(${perfetto_start}, ${anr_ts} - ${timeout_ns})) as perfetto_start,
  printf('%d', COALESCE(${perfetto_end}, ${anr_ts})) as perfetto_end,
  CASE '${anr_type}'
    WHEN 'INPUT_DISPATCHING_TIMEOUT' THEN '输入超时 (5s)'
    WHEN 'INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW' THEN '无焦点窗口输入超时 (5s)'
    WHEN 'BROADCAST_OF_INTENT' THEN '广播超时'
    WHEN 'START_FOREGROUND_SERVICE' THEN '前台服务启动超时'
    WHEN 'EXECUTING_SERVICE' THEN '服务超时'
    WHEN 'CONTENT_PROVIDER_NOT_RESPONDING' THEN 'CP超时'
    WHEN 'JOB_SERVICE_START' THEN 'JobService onStartJob 超时'
    WHEN 'JOB_SERVICE_STOP' THEN 'JobService onStopJob 超时'
    WHEN 'JOB_SERVICE_BIND' THEN 'JobService bind 超时'
    WHEN 'SYSTEM_SERVER_WATCHDOG_TIMEOUT' THEN 'system_server Watchdog 超时'
    WHEN 'GPU_HANG' THEN 'GPU Hang'
    ELSE '${anr_type}'
  END as type_display

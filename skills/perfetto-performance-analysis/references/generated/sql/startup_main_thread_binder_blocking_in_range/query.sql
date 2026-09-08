-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_binder_blocking_in_range.skill.yaml
-- Source SHA-256: fa1c46b5cd242ec0ea44c94e5a2bb4126e4a8da0d846bd67e74402d88452d20c
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT DISTINCT
  bt.server_process,
  bt.aidl_name,
  bt.client_dur / 1e6 as dur_ms,
  ts.state,
  ts.blocked_function,
  printf('%d', bt.client_ts) as ts_str,
  printf('%d', bt.client_dur) as dur_str,
  CASE
    WHEN bt.client_dur / 1e6 > 50 THEN 'critical'
    WHEN bt.client_dur / 1e6 > 16 THEN 'warning'
    ELSE 'normal'
  END as severity
FROM android_binder_txns bt
JOIN android_startups s ON (
  bt.client_ts >= s.ts AND bt.client_ts <= s.ts + s.dur
  AND (bt.client_process = s.package OR bt.client_process GLOB s.package || ':*')
)
LEFT JOIN thread_state ts ON (
  ts.utid = bt.client_utid
  AND ts.ts >= bt.client_ts
  AND ts.ts < bt.client_ts + bt.client_dur
)
WHERE bt.is_main_thread = 1
  AND bt.is_sync = 1
  AND (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND bt.client_dur > ${min_dur_ns|5000000}
ORDER BY bt.client_dur DESC
LIMIT ${top_k|20}

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  bt.client_ts / 1e6 as ts_ms,
  ROUND(bt.client_dur / 1e6, 2) as dur_ms,
  bt.server_process,
  bt.aidl_name,
  COALESCE(bt.aidl_name, 'unknown') as aidl_interface,
  bt.client_process as process_name,
  -- 时间戳用于详细分析
  printf('%d', bt.client_ts) as binder_ts,
  printf('%d', bt.client_ts + bt.client_dur) as binder_end_ts,
  -- Perfetto 跳转参数（前后各扩展 10ms）
  printf('%d', CAST(bt.client_ts - 10000000 AS INTEGER)) as perfetto_start,
  printf('%d', CAST(bt.client_ts + bt.client_dur + 10000000 AS INTEGER)) as perfetto_end,
  CASE
    WHEN bt.client_dur / 1e6 > ${slow_binder_critical_ms|50} THEN 'critical'
    WHEN bt.client_dur / 1e6 > ${slow_binder_warning_ms|16} THEN 'warning'
    WHEN bt.client_dur / 1e6 > 8 THEN 'notice'
    ELSE 'normal'
  END as severity
FROM android_binder_txns bt
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND bt.is_sync = 1
  AND bt.is_main_thread = 1
ORDER BY bt.client_dur DESC
LIMIT 20

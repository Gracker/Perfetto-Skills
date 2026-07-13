-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  COUNT(*) as total_txns,
  SUM(CASE WHEN is_sync = 1 THEN 1 ELSE 0 END) as sync_txns,
  SUM(CASE WHEN is_sync = 0 THEN 1 ELSE 0 END) as async_txns,
  -- 使用正确的列名 is_main_thread
  SUM(CASE WHEN is_main_thread = 1 THEN 1 ELSE 0 END) as main_thread_txns,
  ROUND(AVG(client_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(client_dur) / 1e6, 2) as max_dur_ms,
  SUM(client_dur) / 1e6 as total_dur_ms,
  SUM(CASE WHEN client_dur / 1e6 > 10 THEN 1 ELSE 0 END) as slow_calls_count,
  -- 主线程慢调用
  SUM(CASE WHEN is_main_thread = 1 AND client_dur / 1e6 > 16 THEN 1 ELSE 0 END) as main_thread_slow_count,
  CASE
    WHEN MAX(client_dur) / 1e6 > ${slow_binder_critical_ms|50} * 2 THEN '严重'
    WHEN MAX(client_dur) / 1e6 > ${slow_binder_critical_ms|50} THEN '需优化'
    WHEN MAX(client_dur) / 1e6 > ${slow_binder_warning_ms|16} THEN '良好'
    ELSE '优秀'
  END as rating
FROM android_binder_txns bt
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})

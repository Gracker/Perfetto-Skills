-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  COALESCE(bt.aidl_name, 'unknown') as aidl_interface,
  bt.server_process,
  COUNT(*) as call_count,
  SUM(bt.client_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(bt.client_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_dur_ms,
  -- 主线程调用统计
  SUM(CASE WHEN bt.is_main_thread = 1 THEN 1 ELSE 0 END) as main_thread_count,
  SUM(CASE WHEN bt.is_main_thread = 1 THEN bt.client_dur ELSE 0 END) / 1e6 as main_thread_dur_ms,
  -- 同步/异步
  SUM(CASE WHEN bt.is_sync = 1 THEN 1 ELSE 0 END) as sync_count
FROM android_binder_txns bt
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
GROUP BY COALESCE(bt.aidl_name, 'unknown'), bt.server_process
ORDER BY total_dur_ms DESC
LIMIT 15

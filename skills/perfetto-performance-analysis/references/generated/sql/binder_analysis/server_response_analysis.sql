-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  bt.server_process,
  COALESCE(bt.aidl_name, 'unknown') as aidl_interface,
  COUNT(*) as call_count,
  -- 客户端等待 vs 服务端处理
  SUM(bt.client_dur) / 1e6 as total_client_wait_ms,
  SUM(bt.server_dur) / 1e6 as total_server_process_ms,
  ROUND(AVG(bt.server_dur) / 1e6, 2) as avg_server_dur_ms,
  ROUND(MAX(bt.server_dur) / 1e6, 2) as max_server_dur_ms,
  -- 传输开销 = client_dur - server_dur
  ROUND(AVG(bt.client_dur - bt.server_dur) / 1e6, 2) as avg_transport_overhead_ms
FROM android_binder_txns bt
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND bt.is_sync = 1
GROUP BY bt.server_process, COALESCE(bt.aidl_name, 'unknown')
ORDER BY total_client_wait_ms DESC
LIMIT 15

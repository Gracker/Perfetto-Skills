-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: be42a4750a322322b4d24e8f51e764fd4a4ba09e3c3d943dca53f0ea8eb0971d

SELECT
  bt.client_process,
  COALESCE(bt.aidl_name, 'unknown') as aidl_interface,
  COUNT(*) as call_count,
  SUM(bt.server_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(bt.server_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(bt.server_dur) / 1e6, 2) as max_dur_ms
FROM android_binder_txns bt
WHERE bt.server_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
GROUP BY bt.client_process, COALESCE(bt.aidl_name, 'unknown')
ORDER BY total_dur_ms DESC
LIMIT 15

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_root_cause.skill.yaml
-- Source SHA-256: bbf84b8491afbaad8a2a80e57d0fba5940008d70944ce362ad6f03dcc476115d
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  bd.reason,
  bd.reason_type,
  COUNT(DISTINCT bd.binder_txn_id) as txn_count,
  ROUND(SUM(bd.dur) / 1e6, 2) as total_dur_ms
FROM android_binder_client_server_breakdown bd
JOIN android_binder_txns bt ON bd.binder_txn_id = bt.binder_txn_id
  AND bd.binder_reply_id = bt.binder_reply_id
WHERE bt.is_sync = 1
  AND ('${process_name}' = '' OR bt.client_process = '${process_name}' OR bt.client_process GLOB '${process_name}:*')
  AND bt.client_dur > ${min_dur_ms|1} * 1000000
  AND (${start_ts} IS NULL OR bt.client_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
GROUP BY bd.reason, bd.reason_type
ORDER BY total_dur_ms DESC

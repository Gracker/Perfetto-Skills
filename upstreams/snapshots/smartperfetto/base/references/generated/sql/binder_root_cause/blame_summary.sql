-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_root_cause.skill.yaml
-- Source SHA-256: 9fb3e26f37f2a7dead03e0b85dda71300e9c3c216b4676072b9ef31385ea33ec
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  bd.reason,
  bd.reason_type,
  COUNT(DISTINCT bd.binder_txn_id) as txn_count,
  ROUND(SUM(bd.dur) / 1e6, 2) as total_dur_ms
FROM android_binder_client_server_breakdown bd
JOIN android_binder_txns bt ON bd.binder_txn_id = bt.binder_txn_id
  AND bd.binder_reply_id = bt.binder_reply_id
WHERE bt.is_sync = 1
  AND (bt.client_process GLOB '${process_name}*' OR '${process_name}' = '')
  AND bt.client_dur > ${min_dur_ms|1} * 1000000
  AND (${start_ts} IS NULL OR bt.client_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
GROUP BY bd.reason, bd.reason_type
ORDER BY total_dur_ms DESC

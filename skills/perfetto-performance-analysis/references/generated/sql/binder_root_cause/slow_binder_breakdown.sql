-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_root_cause.skill.yaml
-- Source SHA-256: 9fb3e26f37f2a7dead03e0b85dda71300e9c3c216b4676072b9ef31385ea33ec
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH slow_txns AS (
  SELECT binder_txn_id, binder_reply_id, client_ts, client_dur, server_dur,
         aidl_name, client_process, server_process
  FROM android_binder_txns
  WHERE is_sync = 1
    AND (client_process GLOB '${process_name}*' OR '${process_name}' = '')
    AND client_dur > ${min_dur_ms|1} * 1000000
    AND (${start_ts} IS NULL OR client_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR client_ts < ${end_ts})
  ORDER BY client_dur DESC
  LIMIT 20
)
SELECT
  COALESCE(st.aidl_name, 'unknown') as interface,
  st.server_process,
  ROUND(st.client_dur / 1e6, 2) as client_dur_ms,
  ROUND(st.server_dur / 1e6, 2) as server_dur_ms,
  bd.reason,
  bd.reason_type,
  ROUND(SUM(bd.dur) / 1e6, 2) as reason_dur_ms,
  ROUND(100.0 * SUM(bd.dur) / st.client_dur, 1) as reason_pct
FROM slow_txns st
JOIN android_binder_client_server_breakdown bd
  ON st.binder_txn_id = bd.binder_txn_id
  AND st.binder_reply_id = bd.binder_reply_id
GROUP BY st.binder_txn_id, bd.reason, bd.reason_type
ORDER BY st.client_dur DESC, reason_dur_ms DESC

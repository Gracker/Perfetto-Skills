-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: be42a4750a322322b4d24e8f51e764fd4a4ba09e3c3d943dca53f0ea8eb0971d

SELECT
  bt.client_process as process_name,
  COUNT(*) as txn_count,
  ROUND(SUM(bt.client_dur) / 1e6, 2) as total_client_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_dur_ms
FROM android_binder_txns bt
WHERE (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND (('${package}' = '' OR bt.client_process = '${package}' OR bt.client_process GLOB '${package}:*') OR '${package}' = '')
GROUP BY bt.client_process
ORDER BY txn_count DESC, total_client_ms DESC
LIMIT 1

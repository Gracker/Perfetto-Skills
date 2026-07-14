-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  bt.client_process as process_name,
  COUNT(*) as txn_count,
  ROUND(SUM(bt.client_dur) / 1e6, 2) as total_client_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_dur_ms
FROM android_binder_txns bt
WHERE (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND (bt.client_process GLOB '${package}*' OR '${package}' = '')
GROUP BY bt.client_process
ORDER BY txn_count DESC, total_client_ms DESC
LIMIT 1

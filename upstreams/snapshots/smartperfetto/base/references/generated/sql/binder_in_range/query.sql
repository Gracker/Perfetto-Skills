-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_in_range.skill.yaml
-- Source SHA-256: 3090864d8a14556995865f69ccf951cc39e5c1be1a8fca9fe2a2baf94d282e04
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  client_process,
  server_process,
  COUNT(*) as call_count,
  SUM(client_dur) / 1e6 as total_client_ms,
  MAX(client_dur) / 1e6 as max_delay_ms,
  AVG(client_dur) / 1e6 as avg_delay_ms,
  SUM(CASE WHEN client_dur > 10000000 THEN 1 ELSE 0 END) as slow_calls
FROM android_binder_txns
WHERE (${start_ts} IS NULL OR client_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR client_ts < ${end_ts})
  AND (client_process GLOB '${package}*' OR '${package}' = '')
GROUP BY client_process, server_process
HAVING total_client_ms > 1
ORDER BY total_client_ms DESC

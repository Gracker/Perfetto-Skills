-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_in_range.skill.yaml
-- Source SHA-256: 1f3c07eaa19d4249b09850bb9425b7394450088bee25f08b416e472519f725e0
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
  AND (('${package}' = '' OR client_process = '${package}' OR client_process GLOB '${package}:*') OR '${package}' = '')
GROUP BY client_process, server_process
HAVING total_client_ms > 1
ORDER BY total_client_ms DESC

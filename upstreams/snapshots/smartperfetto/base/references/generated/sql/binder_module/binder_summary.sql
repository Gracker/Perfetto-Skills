-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: a0d3130ef46dca29cdc90ca4ef4288c06f405f36121cc8c58ee997b455134811

SELECT
  client_process AS caller_process,
  server_process,
  aidl_name AS interface,
  COUNT(*) AS call_count,
  CAST(SUM(client_dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(client_dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(client_dur) / 1e6 AS REAL) AS max_ms,
  SUM(CASE WHEN is_sync = 1 THEN 1 ELSE 0 END) AS sync_count
FROM android_binder_txns
WHERE '${package}' = ''
  OR client_process = '${package}' OR client_process GLOB '${package}:*'
  OR server_process = '${package}' OR server_process GLOB '${package}:*'
GROUP BY client_process, server_process, aidl_name
HAVING total_ms > 1
ORDER BY total_ms DESC
LIMIT 20

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: a0d3130ef46dca29cdc90ca4ef4288c06f405f36121cc8c58ee997b455134811

SELECT
  server_process,
  aidl_name AS interface,
  COUNT(*) AS block_count,
  CAST(SUM(client_dur) / 1e6 AS INTEGER) AS total_block_ms,
  CAST(AVG(client_dur) / 1e6 AS REAL) AS avg_block_ms
FROM android_binder_txns
WHERE is_sync = 1
  AND client_dur > 2000000  -- > 2ms considered blocking
  AND ('${package}' = '' OR client_process = '${package}' OR client_process GLOB '${package}:*')
GROUP BY server_process, aidl_name
ORDER BY total_block_ms DESC
LIMIT 10

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: ac801a61aa0de9d819d8b84e2ccfcfb07d76ca816e88e5fde8c63d1832343e4a
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  server_process,
  aidl_name AS interface,
  COUNT(*) AS block_count,
  CAST(SUM(client_dur) / 1e6 AS INTEGER) AS total_block_ms,
  CAST(AVG(client_dur) / 1e6 AS REAL) AS avg_block_ms
FROM android_binder_txns
WHERE is_sync = 1
  AND client_dur > 2000000  -- > 2ms considered blocking
  AND client_process LIKE '%${package}%'
GROUP BY server_process, aidl_name
ORDER BY total_block_ms DESC
LIMIT 10

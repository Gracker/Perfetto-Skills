-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: ac801a61aa0de9d819d8b84e2ccfcfb07d76ca816e88e5fde8c63d1832343e4a
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

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
WHERE client_process LIKE '%${package}%'
  OR server_process LIKE '%${package}%'
GROUP BY client_process, server_process, aidl_name
HAVING total_ms > 1
ORDER BY total_ms DESC
LIMIT 20

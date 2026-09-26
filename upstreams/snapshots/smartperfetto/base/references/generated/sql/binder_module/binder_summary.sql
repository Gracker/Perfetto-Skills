-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: 39cf89a226f58bb4fcafd742d990b0c443ee3aae24681b02e3b3d065080fbf32
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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

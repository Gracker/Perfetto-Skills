-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: 39cf89a226f58bb4fcafd742d990b0c443ee3aae24681b02e3b3d065080fbf32
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

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

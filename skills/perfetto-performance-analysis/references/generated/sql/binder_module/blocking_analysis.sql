-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: 39cf89a226f58bb4fcafd742d990b0c443ee3aae24681b02e3b3d065080fbf32
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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

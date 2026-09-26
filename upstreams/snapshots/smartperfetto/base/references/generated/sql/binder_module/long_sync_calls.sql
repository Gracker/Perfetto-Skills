-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: 39cf89a226f58bb4fcafd742d990b0c443ee3aae24681b02e3b3d065080fbf32
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  client_ts AS ts,
  client_process AS caller_process,
  server_process,
  aidl_name AS interface,
  CAST(client_dur / 1e6 AS REAL) AS dur_ms,
  client_tid,
  server_tid
FROM android_binder_txns
WHERE is_sync = 1
  AND client_dur > 5000000  -- > 5ms
  AND ('${package}' = ''
    OR client_process = '${package}' OR client_process GLOB '${package}:*'
    OR server_process = '${package}' OR server_process GLOB '${package}:*')
ORDER BY client_dur DESC
LIMIT 30

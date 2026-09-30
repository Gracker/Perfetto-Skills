-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: e374d828a42b45b2f0c2de0b02ca10fd40049073b3e8b52aedb4724592469f73

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

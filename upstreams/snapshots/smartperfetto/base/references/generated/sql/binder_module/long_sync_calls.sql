-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/binder_module.skill.yaml
-- Source SHA-256: ac801a61aa0de9d819d8b84e2ccfcfb07d76ca816e88e5fde8c63d1832343e4a
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
  AND (client_process LIKE '%${package}%' OR server_process LIKE '%${package}%')
ORDER BY client_dur DESC
LIMIT 30

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 601e2490169eb1b6b6c35ac9f2bc34e6c55075bfa03ef83af956a9e886ebf863
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

SELECT
  server_process as interface,
  COUNT(*) as count,
  ROUND(SUM(client_dur) / 1e6, 2) as dur_ms,
  ROUND(MAX(client_dur) / 1e6, 2) as max_ms,
  SUM(CASE WHEN is_sync = 1 THEN 1 ELSE 0 END) as sync_count
FROM android_binder_txns
WHERE client_ts >= ${start_ts}
  AND client_ts < ${end_ts}
  AND (${__process_scope.upid} IS NULL OR client_upid = ${__process_scope.upid})
  AND (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR client_process = '${package}' OR client_process GLOB '${package}:*')
GROUP BY server_process
HAVING dur_ms > 0.5
ORDER BY dur_ms DESC
LIMIT 5

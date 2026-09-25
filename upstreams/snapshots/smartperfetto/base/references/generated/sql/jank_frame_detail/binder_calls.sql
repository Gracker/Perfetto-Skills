-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 960209f7b80fdced155eebd63d089f78ed033bbbb671d3a56279b95f8f92fc2b
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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

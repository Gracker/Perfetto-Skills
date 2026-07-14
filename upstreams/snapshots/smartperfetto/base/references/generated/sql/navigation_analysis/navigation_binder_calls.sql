-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 1ebfd2d987dc15689b41fd76a43570d53d80c2054b688b131b355b37c3585b99
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  bt.server_process,
  bt.aidl_name,
  COUNT(*) as call_count,
  ROUND(SUM(bt.client_dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(bt.client_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_dur_ms,
  SUM(CASE WHEN bt.is_main_thread = 1 THEN 1 ELSE 0 END) as main_thread_calls
FROM android_binder_txns bt
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND bt.client_dur > 1000000
GROUP BY bt.server_process, bt.aidl_name
ORDER BY total_dur_ms DESC
LIMIT 15

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_sync_binder_in_range.skill.yaml
-- Source SHA-256: c4236d3d3ce4b56f36f7b964ca12ff21494c32f48541300689d7acde8a6a4d7f

SELECT
  bt.server_process,
  bt.aidl_name,
  COUNT(*) as call_count,
  SUM(bt.client_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(bt.client_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_dur_ms,
  ROUND(100.0 * SUM(bt.client_dur) / s.dur, 1) as percent_of_startup,
  -- Window aggregates see every group before LIMIT: totals over the whole startup.
  ROUND(100.0 * SUM(SUM(bt.client_dur)) OVER (PARTITION BY s.startup_id) / s.dur, 1) as all_percent_of_startup
FROM android_binder_txns bt
JOIN android_startups s ON (
  bt.client_ts >= s.ts AND bt.client_ts <= s.ts + s.dur
  AND (bt.client_process = s.package OR bt.client_process GLOB s.package || ':*')
)
WHERE bt.is_main_thread = 1
  AND bt.is_sync = 1
  AND (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
GROUP BY bt.server_process, bt.aidl_name, s.startup_id
ORDER BY total_dur_ms DESC
LIMIT ${top_k|15}

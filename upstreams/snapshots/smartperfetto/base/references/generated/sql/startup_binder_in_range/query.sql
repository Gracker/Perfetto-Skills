-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_binder_in_range.skill.yaml
-- Source SHA-256: 634089d0758acaec85224ca0440cd8e33c26da6dc537b93e0ee0f3e54d663f6c
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  bt.server_process,
  bt.aidl_name,
  COUNT(*) as call_count,
  SUM(bt.client_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(bt.client_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_dur_ms,
  SUM(CASE WHEN bt.is_main_thread THEN 1 ELSE 0 END) as main_thread_calls,
  '${startup_type}' as startup_type,
  ROUND(100.0 * SUM(bt.client_dur) / s.dur, 1) as percent_of_startup
FROM android_binder_txns bt
JOIN android_startups s ON (
  bt.client_ts >= s.ts AND bt.client_ts <= s.ts + s.dur
  AND bt.client_process GLOB s.package || '*'
)
WHERE (s.package GLOB '${package}*' OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
GROUP BY bt.server_process, bt.aidl_name, s.startup_id
ORDER BY total_dur_ms DESC
LIMIT ${top_k|15}

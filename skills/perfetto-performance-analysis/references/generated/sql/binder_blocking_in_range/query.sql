-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_blocking_in_range.skill.yaml
-- Source SHA-256: 9e8a00b4d97ea3da1311a06c95ec77bc9e499ff4cd0237d28bebfbb1c720ee48
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH target_main_thread AS (
  SELECT t.tid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND t.tid = p.pid  -- 主线程
)
SELECT
  bt.server_process,
  COALESCE(bt.aidl_name, bt.server_thread, 'unknown') as interface,
  COUNT(*) as call_count,
  ROUND(SUM(bt.client_dur) / 1e6, 2) as total_block_ms,
  ROUND(SUM(bt.server_dur) / 1e6, 2) as server_exec_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_block_ms,
  MAX(CASE WHEN bt.client_tid IN (SELECT tid FROM target_main_thread) THEN 1 ELSE 0 END) as is_main_blocked
FROM android_binder_txns bt
WHERE (${start_ts} IS NULL OR bt.client_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND bt.is_sync = 1  -- 只关注同步调用
  AND (bt.client_process GLOB '${package}*' OR '${package}' = '')
  AND bt.client_dur > 500000  -- > 0.5ms
GROUP BY bt.server_process, interface
HAVING total_block_ms > 0.5
ORDER BY total_block_ms DESC
LIMIT 10

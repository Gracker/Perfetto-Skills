-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

SELECT
  process_name,
  COUNT(*) AS contention_count,
  ROUND(SUM(dur) / 1e6, 2) AS total_blocked_time_ms,
  ROUND(AVG(dur) / 1e6, 2) AS avg_blocked_time_ms,
  ROUND(MAX(dur) / 1e6, 2) AS max_blocked_time_ms,
  SUM(CASE WHEN is_blocked_thread_main THEN 1 ELSE 0 END) AS main_thread_contentions,
  ROUND(AVG(waiter_count), 1) AS avg_waiters
FROM android_monitor_contention
WHERE
  CASE WHEN '${process_name}' != ''
       THEN process_name GLOB '*${process_name}*'
       ELSE 1 END
  AND dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY process_name
ORDER BY total_blocked_time_ms DESC

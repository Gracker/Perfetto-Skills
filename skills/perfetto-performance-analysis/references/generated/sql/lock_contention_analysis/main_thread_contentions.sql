-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  process_name,
  short_blocking_method,
  blocking_thread_name,
  is_blocking_thread_main AS blocker_is_main,
  COUNT(*) AS contention_count,
  ROUND(SUM(dur) / 1e6, 2) AS total_blocked_ms,
  ROUND(AVG(dur) / 1e6, 2) AS avg_blocked_ms,
  ROUND(MAX(dur) / 1e6, 2) AS max_blocked_ms,
  ROUND(AVG(waiter_count), 1) AS avg_waiters
FROM android_monitor_contention
WHERE is_blocked_thread_main = 1
  AND CASE WHEN '${process_name}' != ''
           THEN process_name GLOB '*${process_name}*'
           ELSE 1 END
  AND dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY process_name, short_blocking_method, blocking_thread_name
ORDER BY total_blocked_ms DESC
LIMIT 30

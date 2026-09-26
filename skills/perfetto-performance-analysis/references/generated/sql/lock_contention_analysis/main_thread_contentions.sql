-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
           THEN (process_name = '${process_name}' OR process_name GLOB '${process_name}:*')
           ELSE 1 END
  AND dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY process_name, short_blocking_method, blocking_thread_name
ORDER BY total_blocked_ms DESC
LIMIT 30

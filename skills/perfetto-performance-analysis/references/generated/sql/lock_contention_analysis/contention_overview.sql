-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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

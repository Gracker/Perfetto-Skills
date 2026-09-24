-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

SELECT
  short_blocking_method,
  blocking_src,
  COUNT(*) AS contention_count,
  COUNT(DISTINCT blocked_utid) AS unique_waiters,
  ROUND(SUM(dur) / 1e6, 2) AS total_contention_ms,
  MAX(waiter_count) AS max_waiters
FROM android_monitor_contention
WHERE CASE WHEN '${process_name}' != ''
           THEN process_name GLOB '*${process_name}*'
           ELSE 1 END
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY short_blocking_method, blocking_src
ORDER BY total_contention_ms DESC
LIMIT 20

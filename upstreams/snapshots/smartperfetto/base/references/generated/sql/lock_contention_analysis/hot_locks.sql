-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

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

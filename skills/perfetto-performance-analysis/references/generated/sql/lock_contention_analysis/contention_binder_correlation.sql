-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

SELECT
  c.process_name,
  c.short_blocking_method,
  c.binder_reply_tid IS NOT NULL AS in_binder_txn,
  COUNT(*) AS contention_count,
  ROUND(AVG(c.dur) / 1e6, 2) AS avg_contention_ms
FROM android_monitor_contention c
WHERE CASE WHEN '${process_name}' != ''
           THEN c.process_name GLOB '*${process_name}*'
           ELSE 1 END
  AND c.dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
  AND (${start_ts} IS NULL OR c.ts + c.dur > ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY c.process_name, c.short_blocking_method, in_binder_txn
ORDER BY contention_count DESC
LIMIT 30

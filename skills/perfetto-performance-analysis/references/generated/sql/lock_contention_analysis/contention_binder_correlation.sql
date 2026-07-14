-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

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

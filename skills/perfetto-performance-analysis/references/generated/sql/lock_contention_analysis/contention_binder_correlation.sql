-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  c.process_name,
  c.short_blocking_method,
  c.binder_reply_tid IS NOT NULL AS in_binder_txn,
  COUNT(*) AS contention_count,
  ROUND(AVG(c.dur) / 1e6, 2) AS avg_contention_ms
FROM android_monitor_contention c
WHERE CASE WHEN '${process_name}' != ''
           THEN (c.process_name = '${process_name}' OR c.process_name GLOB '${process_name}:*')
           ELSE 1 END
  AND c.dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
  AND (${start_ts} IS NULL OR c.ts + c.dur > ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY c.process_name, c.short_blocking_method, in_binder_txn
ORDER BY contention_count DESC
LIMIT 30

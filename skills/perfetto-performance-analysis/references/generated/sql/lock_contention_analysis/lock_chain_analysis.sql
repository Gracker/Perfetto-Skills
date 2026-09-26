-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  c.short_blocked_method AS blocked_at,
  c.short_blocking_method AS waiting_for,
  c.blocking_thread_name,
  c.parent_id IS NOT NULL AS has_parent,
  c.child_id IS NOT NULL AS has_child,
  ROUND(c.dur / 1e6, 2) AS blocked_ms,
  c.waiter_count
FROM android_monitor_contention_chain c
WHERE (c.parent_id IS NOT NULL OR c.child_id IS NOT NULL)
  AND CASE WHEN '${process_name}' != ''
           THEN (c.process_name = '${process_name}' OR c.process_name GLOB '${process_name}:*')
           ELSE 1 END
  AND (${start_ts} IS NULL OR c.ts + c.dur > ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
ORDER BY c.dur DESC
LIMIT 50

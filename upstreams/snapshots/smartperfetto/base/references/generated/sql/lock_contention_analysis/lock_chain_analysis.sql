-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

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
           THEN c.process_name GLOB '*${process_name}*'
           ELSE 1 END
  AND (${start_ts} IS NULL OR c.ts + c.dur > ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
ORDER BY c.dur DESC
LIMIT 50

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/lock_contention_in_range.skill.yaml
-- Source SHA-256: 5ab49bd436eb79f8d1bdc21b06e2b662481cb3335728c1776c55c8b0fab0f99b
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  short_blocking_method as blocking_method,
  blocking_thread_name,
  short_blocked_method as blocked_method,
  blocked_thread_name,
  is_blocked_thread_main as main_blocked,
  ROUND(dur / 1e6, 2) as wait_ms,
  waiter_count,
  'java_monitor' as lock_type
FROM android_monitor_contention
WHERE ts >= ${start_ts}
  AND ts < ${end_ts}
  AND (process_name GLOB '${package}*' OR '${package}' = '')
  AND dur >= 1000000
ORDER BY dur DESC

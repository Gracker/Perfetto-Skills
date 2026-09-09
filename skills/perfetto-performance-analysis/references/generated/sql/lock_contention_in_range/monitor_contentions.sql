-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/lock_contention_in_range.skill.yaml
-- Source SHA-256: 660f675d614aec2af8885125bcb62d2a5410b5318a01e545990ff3642f53a566
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
  AND (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
  AND dur >= 1000000
ORDER BY dur DESC

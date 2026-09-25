-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 960209f7b80fdced155eebd63d089f78ed033bbbb671d3a56279b95f8f92fc2b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  short_blocking_method as blocking_method,
  blocking_thread_name,
  short_blocked_method as blocked_method,
  blocked_thread_name,
  CASE WHEN is_blocked_thread_main THEN 1 ELSE 0 END as main_blocked,
  ROUND(dur / 1e6, 2) as wait_ms,
  waiter_count
FROM android_monitor_contention
WHERE ts >= ${start_ts}
  AND ts < ${end_ts}
  AND (${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid})
  AND (
    ${__process_scope.upid} IS NOT NULL
    OR '${package}' = ''
    OR process_name = '${package}'
    OR process_name GLOB '${package}:*'
  )
  AND dur >= 500000
ORDER BY dur DESC
LIMIT 5

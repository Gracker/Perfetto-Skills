-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: a0211e3d982714457a51437e411533797d8d6b214b85d9f67ce0d80ba4ad4c61

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

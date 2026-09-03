-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: cc19de68a5c179e17af405bf32f9ca75f56af0c5a4ccf970ede72790c558942b
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
  AND (
    '${package}' = ''
    OR process_name = '${package}'
    OR process_name GLOB '${package}:*'
  )
  AND dur >= 500000
ORDER BY dur DESC
LIMIT 5

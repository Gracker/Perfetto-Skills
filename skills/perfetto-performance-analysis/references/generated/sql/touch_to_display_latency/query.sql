-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/touch_to_display_latency.skill.yaml
-- Source SHA-256: 1eae013ffdaba631ee4959847e00cae0c4786b003c28a3a01975e8592b873da3
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

SELECT
  printf('%d', dispatch_ts) as input_ts,
  process_name,
  event_type,
  event_action,
  ROUND(dispatch_latency_dur / 1e6, 2) as dispatch_latency_ms,
  ROUND(handling_latency_dur / 1e6, 2) as handling_latency_ms,
  ROUND(ack_latency_dur / 1e6, 2) as ack_latency_ms,
  ROUND(total_latency_dur / 1e6, 2) as total_latency_ms,
  ROUND(end_to_end_latency_dur / 1e6, 2) as e2e_latency_ms,
  normalized_event_channel as normalized_channel,
  is_speculative_frame,
  CASE
    WHEN total_latency_dur / 1e6 < 32 THEN '优秀'
    WHEN total_latency_dur / 1e6 < 64 THEN '良好'
    WHEN total_latency_dur / 1e6 < 100 THEN '可接受'
    WHEN total_latency_dur / 1e6 < 150 THEN '需优化'
    ELSE '严重'
  END as rating
FROM android_input_events
WHERE (process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
  AND ('${event_type}' = '' OR event_type = '${event_type}')
ORDER BY total_latency_dur DESC

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_events_in_range.skill.yaml
-- Source SHA-256: 55d6681383a486d2bb4ba6b2229acb5445d935eb1b8e27148503595a16ff137b
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  printf('%d', dispatch_ts) as event_ts,
  event_type,
  event_action,
  ROUND(dispatch_latency_dur / 1e6, 2) as dispatch_latency_ms,
  ROUND(handling_latency_dur / 1e6, 2) as handling_latency_ms,
  ROUND(ack_latency_dur / 1e6, 2) as ack_latency_ms,
  ROUND(total_latency_dur / 1e6, 2) as total_latency_ms,
  ROUND(end_to_end_latency_dur / 1e6, 2) as e2e_latency_ms,
  process_name,
  normalized_event_channel as normalized_channel,
  CASE
    WHEN total_latency_dur / 1e6 > 200 THEN '严重延迟'
    WHEN total_latency_dur / 1e6 > 100 THEN '延迟偏高'
    WHEN total_latency_dur / 1e6 > 50 THEN '轻微延迟'
    ELSE '正常'
  END as dispatch_status
FROM android_input_events
WHERE (process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
  AND ('${event_type}' = '' OR event_type = '${event_type}')
  AND ('${event_action}' = '' OR event_action = '${event_action}')
ORDER BY dispatch_ts ASC

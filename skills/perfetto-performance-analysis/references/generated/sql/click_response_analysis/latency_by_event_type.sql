-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: c36d5e8f865c21530d0538a9a549cc6cacafc1b68da63ba7f2d6e83052d6a08f
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  event_type,
  event_action,
  COUNT(*) as count,
  ROUND(AVG(total_latency_dur) / 1e6, 2) as avg_latency_ms,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_latency_ms,
  ROUND(AVG(handling_latency_dur) / 1e6, 2) as avg_handling_ms,
  -- 慢事件数
  SUM(CASE WHEN total_latency_dur / 1e6 > ${slow_event_threshold_ms|100} THEN 1 ELSE 0 END) as slow_events
FROM android_input_events
WHERE process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
GROUP BY event_type, event_action
ORDER BY avg_latency_ms DESC

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: a4b934d0ea9e3be026e38cff778d34fc9482780ab04a5fd0a4d3f6542323e245
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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

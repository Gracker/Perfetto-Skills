-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: a4b934d0ea9e3be026e38cff778d34fc9482780ab04a5fd0a4d3f6542323e245
-- Source commit: bc007586871a720aed82537913617c64fb95a459

SELECT
  normalized_event_channel as window,
  COUNT(*) as count,
  ROUND(AVG(total_latency_dur) / 1e6, 2) as avg_latency_ms,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_latency_ms,
  ROUND(AVG(handling_latency_dur) / 1e6, 2) as avg_handling_ms,
  SUM(CASE WHEN total_latency_dur / 1e6 > ${slow_event_threshold_ms|100} THEN 1 ELSE 0 END) as slow_events
FROM android_input_events
WHERE process_name = '${target_process.data[0].process_name}'
  AND normalized_event_channel IS NOT NULL
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
GROUP BY normalized_event_channel
HAVING COUNT(*) > 1
ORDER BY avg_latency_ms DESC

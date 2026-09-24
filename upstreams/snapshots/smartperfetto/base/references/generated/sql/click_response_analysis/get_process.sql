-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: a4b934d0ea9e3be026e38cff778d34fc9482780ab04a5fd0a4d3f6542323e245
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  process_name,
  COUNT(*) as event_count,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_total_ms
FROM android_input_events
WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
GROUP BY process_name
ORDER BY event_count DESC, max_total_ms DESC
LIMIT 1

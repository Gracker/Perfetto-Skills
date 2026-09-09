-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: c36d5e8f865c21530d0538a9a549cc6cacafc1b68da63ba7f2d6e83052d6a08f
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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

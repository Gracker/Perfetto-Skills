-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: 0f803fbe7f82fcbcf288bfe2fb88bab8e0ad54cb2df2995d710a285a31b733c6
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  process_name,
  COUNT(*) as event_count,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_total_ms
FROM android_input_events
WHERE (process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
GROUP BY process_name
ORDER BY event_count DESC, max_total_ms DESC
LIMIT 1

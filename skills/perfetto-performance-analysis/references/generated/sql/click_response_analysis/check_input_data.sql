-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: 0f803fbe7f82fcbcf288bfe2fb88bab8e0ad54cb2df2995d710a285a31b733c6
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  COUNT(*) as event_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_input_events
WHERE (process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

SELECT
  COUNT(*) as contention_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_monitor_contention
WHERE
  CASE WHEN '${process_name}' != ''
       THEN process_name GLOB '*${process_name}*'
       ELSE 1 END
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})

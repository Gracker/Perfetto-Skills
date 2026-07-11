-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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

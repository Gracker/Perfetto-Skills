-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  COUNT(*) as contention_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_monitor_contention
WHERE
  CASE WHEN '${process_name}' != ''
       THEN (process_name = '${process_name}' OR process_name GLOB '${process_name}:*')
       ELSE 1 END
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})

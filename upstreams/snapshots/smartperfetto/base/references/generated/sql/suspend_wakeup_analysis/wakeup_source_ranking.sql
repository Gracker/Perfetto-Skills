-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  item as wakeup_source,
  type as wakeup_type,
  COUNT(*) as wakeup_count,
  ROUND(SUM(dur) / 1e9, 2) as total_awake_sec,
  ROUND(AVG(dur) / 1e9, 2) as avg_awake_sec
FROM android_wakeups
WHERE (item GLOB '*${wakeup_source}*' OR '${wakeup_source}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY item, type
ORDER BY wakeup_count DESC
LIMIT 30

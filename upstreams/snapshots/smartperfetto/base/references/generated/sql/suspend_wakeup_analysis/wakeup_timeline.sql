-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  printf('%d', ts) as event_ts,
  ROUND(dur / 1e9, 2) as awake_duration_sec,
  type as wakeup_type,
  item as wakeup_source,
  suspend_quality,
  on_device_attribution
FROM android_wakeups
WHERE (item GLOB '*${wakeup_source}*' OR '${wakeup_source}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts
LIMIT 100

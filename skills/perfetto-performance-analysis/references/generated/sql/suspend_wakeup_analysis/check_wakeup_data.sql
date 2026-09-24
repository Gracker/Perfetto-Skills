-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  COUNT(*) as wakeup_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_wakeups
WHERE (item GLOB '*${wakeup_source}*' OR '${wakeup_source}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})

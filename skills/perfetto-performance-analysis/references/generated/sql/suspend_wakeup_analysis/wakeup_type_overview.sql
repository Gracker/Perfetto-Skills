-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  type as wakeup_type,
  suspend_quality,
  COUNT(*) as wakeup_count,
  ROUND(SUM(dur) / 1e9, 2) as total_awake_time_sec,
  ROUND(AVG(dur) / 1e9, 2) as avg_awake_time_sec
FROM android_wakeups
WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY type, suspend_quality
ORDER BY wakeup_count DESC

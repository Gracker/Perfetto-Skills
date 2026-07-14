-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  power_state,
  COUNT(*) as period_count,
  ROUND(SUM(dur) / 1e9, 2) as total_time_sec,
  ROUND(AVG(dur) / 1e9, 2) as avg_duration_sec,
  ROUND(MAX(dur) / 1e9, 2) as max_duration_sec,
  ROUND(MIN(dur) / 1e9, 2) as min_duration_sec
FROM android_suspend_state
WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY power_state

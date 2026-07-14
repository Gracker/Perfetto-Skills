-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  s.name as slice_name,
  COUNT(*) as count,
  ROUND(SUM(s.dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(s.dur) / 1e6, 2) as max_dur_ms
FROM slice s
WHERE (
    s.name GLOB '*suspend*'
    OR s.name GLOB '*Suspend*'
    OR s.name GLOB '*wakeup*'
    OR s.name GLOB '*Wakeup*'
    OR s.name GLOB '*wake_lock*'
    OR s.name GLOB '*WakeLock*'
    OR s.name GLOB '*power_state*'
  )
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
GROUP BY s.name
ORDER BY total_dur_ms DESC
LIMIT 20

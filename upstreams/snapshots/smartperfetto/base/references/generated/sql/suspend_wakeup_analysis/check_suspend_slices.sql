-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  COUNT(*) as slice_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM slice
WHERE (
    name GLOB '*suspend*'
    OR name GLOB '*Suspend*'
    OR name GLOB '*wakeup*'
    OR name GLOB '*Wakeup*'
    OR name GLOB '*wake_lock*'
    OR name GLOB '*WakeLock*'
    OR name GLOB '*power_state*'
  )
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: 4a2128e808996386dac3b72b899746989b84cc0117844e75b30b84dc52c4a367

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

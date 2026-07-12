-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  backoff_reason,
  backoff_state,
  COUNT(*) as count,
  MAX(backoff_count) as max_backoff_count,
  ROUND(MAX(backoff_millis), 2) as max_backoff_ms,
  ROUND(AVG(backoff_millis), 2) as avg_backoff_ms
FROM android_wakeups
WHERE backoff_reason IS NOT NULL
  AND backoff_reason != 'none'
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY backoff_reason, backoff_state
ORDER BY count DESC

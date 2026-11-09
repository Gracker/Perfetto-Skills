-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: 4a2128e808996386dac3b72b899746989b84cc0117844e75b30b84dc52c4a367

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

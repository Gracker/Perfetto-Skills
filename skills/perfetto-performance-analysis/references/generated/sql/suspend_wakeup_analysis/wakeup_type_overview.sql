-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: 4a2128e808996386dac3b72b899746989b84cc0117844e75b30b84dc52c4a367

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

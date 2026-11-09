-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: 4a2128e808996386dac3b72b899746989b84cc0117844e75b30b84dc52c4a367

SELECT
  printf('%d', ts) as event_ts,
  power_state,
  ROUND(dur / 1e9, 2) as duration_sec
FROM android_suspend_state
WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY dur DESC
LIMIT 20

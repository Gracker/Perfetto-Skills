-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/battery_doze_state_timeline.skill.yaml
-- Source SHA-256: 38c6fc6d472d705aaa1f872ee022272227ec52cff40e8269d1c1f0f44b2cc021

SELECT
  ts,
  ROUND(dur / 1e9, 3) AS dur_sec,
  deep_idle_state
FROM android_deep_idle_state
WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC

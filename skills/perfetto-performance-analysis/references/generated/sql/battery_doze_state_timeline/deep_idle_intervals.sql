-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/battery_doze_state_timeline.skill.yaml
-- Source SHA-256: 76538da9dab1b6f5e68441be298de8fa40633dbe1e8b0cf79d547d49c1f1e4a1
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  ts,
  ROUND(dur / 1e9, 1) AS dur_sec
FROM android_deep_idle_state
WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC

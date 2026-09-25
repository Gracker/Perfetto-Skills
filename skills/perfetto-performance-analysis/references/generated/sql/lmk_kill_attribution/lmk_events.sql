-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/lmk_kill_attribution.skill.yaml
-- Source SHA-256: 1f267129dd343f4693338d1c7e4384b88c383313fe1b950339e31f9c9dfa8c85
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  ts,
  process_name,
  pid,
  oom_score_adj
FROM android_lmk_events
WHERE ('${process_name}' = '' OR process_name = '${process_name}' OR process_name GLOB '${process_name}:*')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC

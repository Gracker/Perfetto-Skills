-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/lmk_kill_attribution.skill.yaml
-- Source SHA-256: 4c299b78e625d37ee05fb8288a3b072ab6151ce29c5f98780a038913d06664ae
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  ts,
  process_name,
  pid,
  oom_score_adj
FROM android_lmk_events
WHERE (process_name GLOB '${process_name}*' OR '${process_name}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC

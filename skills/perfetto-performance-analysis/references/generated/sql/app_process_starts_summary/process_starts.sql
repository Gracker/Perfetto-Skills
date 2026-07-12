-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/app_process_starts_summary.skill.yaml
-- Source SHA-256: 79574f7a0632de56aeb0962a68ebdb293f1668a6dccbc051f8b197654a6349c0
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  process_name,
  process_start_ts,
  ROUND(total_dur / 1e6, 1) AS total_dur_ms,
  reason
FROM android_app_process_starts
WHERE (process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR process_start_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR process_start_ts < ${end_ts})
ORDER BY process_start_ts ASC

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/app_process_starts_summary.skill.yaml
-- Source SHA-256: 79574f7a0632de56aeb0962a68ebdb293f1668a6dccbc051f8b197654a6349c0
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/app_process_starts_summary.skill.yaml
-- Source SHA-256: d6ed1ec16d3db9336e685be79eb01e3f42baea1e5ef2ff0145a20281405a9cbd
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  process_name,
  proc_start_ts AS process_start_ts,
  ROUND(total_dur / 1e6, 1) AS total_dur_ms,
  reason
FROM android_app_process_starts
WHERE (process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR proc_start_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR proc_start_ts < ${end_ts})
ORDER BY proc_start_ts ASC

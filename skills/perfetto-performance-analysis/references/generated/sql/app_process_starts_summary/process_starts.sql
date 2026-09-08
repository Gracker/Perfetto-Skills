-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/app_process_starts_summary.skill.yaml
-- Source SHA-256: b6c52e29a1056ff902bdfb67ff8c9e187457aea4660d8ac95764a4b4c8907df4
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  process_name,
  proc_start_ts AS process_start_ts,
  ROUND(total_dur / 1e6, 1) AS total_dur_ms,
  reason
FROM android_app_process_starts
WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR proc_start_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR proc_start_ts < ${end_ts})
ORDER BY proc_start_ts ASC

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/app_process_starts_summary.skill.yaml
-- Source SHA-256: b6c52e29a1056ff902bdfb67ff8c9e187457aea4660d8ac95764a4b4c8907df4
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

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

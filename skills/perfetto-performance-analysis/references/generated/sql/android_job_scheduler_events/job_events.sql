-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_job_scheduler_events.skill.yaml
-- Source SHA-256: 5afb016bd89088c8c317111e7909bd82a536b14a6e63d3b9b668f4e765304826
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  ts,
  ROUND(dur / 1e6, 2) AS dur_ms,
  job_service_name AS job_name,
  package_name,
  uid
FROM android_job_scheduler_events
WHERE (package_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC

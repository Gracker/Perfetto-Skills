-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_job_scheduler_events.skill.yaml
-- Source SHA-256: ba9540e773bd4ae67b91b141674cfe0b66e89de879fc3d328ea0e98c480c110b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  ts,
  ROUND(dur / 1e6, 2) AS dur_ms,
  job_service_name AS job_name,
  package_name,
  uid
FROM android_job_scheduler_events
WHERE (('${package}' = '' OR package_name = '${package}' OR package_name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC

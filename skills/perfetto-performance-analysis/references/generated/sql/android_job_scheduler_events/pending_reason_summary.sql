-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_job_scheduler_events.skill.yaml
-- Source SHA-256: aa6721a92d941b2fca0139aeba55e46532db1d83720306e4d47b18ac850346bd

SELECT
  s.package_name,
  s.uid,
  r.pending_reason,
  COUNT(DISTINCT s.slice_id) AS completed_job_count,
  COUNT(r.pending_duration_ms) AS known_duration_count,
  COUNT(*) - COUNT(r.pending_duration_ms) AS missing_duration_count,
  SUM(r.pending_duration_ms) AS reported_wait_ms
FROM android_job_scheduler_states_track_events AS s
JOIN android_job_scheduler_pending_reasons_track_events AS r ON r.slice_id = s.slice_id
WHERE ('${package}' = '' OR s.package_name = '${package}' OR s.package_name GLOB '${package}:*')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
GROUP BY s.package_name, s.uid, r.pending_reason
ORDER BY s.package_name, s.uid, r.pending_reason

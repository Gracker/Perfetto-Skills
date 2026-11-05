-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_job_scheduler_events.skill.yaml
-- Source SHA-256: aa6721a92d941b2fca0139aeba55e46532db1d83720306e4d47b18ac850346bd

SELECT CASE
  WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'android_job_scheduler_states_track_events')
    AND EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'android_job_scheduler_pending_reasons_track_events')
  THEN 'runtime_supported'
  ELSE 'runtime_lacks_job_pending_reasons'
END AS status

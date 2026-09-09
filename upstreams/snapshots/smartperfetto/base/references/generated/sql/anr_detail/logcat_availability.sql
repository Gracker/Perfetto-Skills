-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 283e74c341c76d3959624287f046bcc7f85e2b7b1cbe1edfab07c544a01660af
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'android_logs'
  ) THEN 1 ELSE 0 END AS has_android_logs

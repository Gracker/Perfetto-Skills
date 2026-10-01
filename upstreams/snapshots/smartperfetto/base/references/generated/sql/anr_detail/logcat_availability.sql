-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 0be84fe96c0f5e4646a49f1630ef4cfcf6662638c5c42718b3bff9307513577f

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'android_logs'
  ) THEN 1 ELSE 0 END AS has_android_logs

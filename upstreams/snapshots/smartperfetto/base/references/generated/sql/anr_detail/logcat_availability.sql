-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 5373394d55d3a035fc472bc4f0684c504581b9760f01a90d2c596cd88d35f92e

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'android_logs'
  ) THEN 1 ELSE 0 END AS has_android_logs

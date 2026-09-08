-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 89b4d18013a6f905876e70327ad35d2b6b486969311b984b2eabdcf58eeffa90
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_binder_txns'
    ) THEN 1
    ELSE 0
  END as has_binder_table

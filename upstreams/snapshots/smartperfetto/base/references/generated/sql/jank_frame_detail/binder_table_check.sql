-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: cced6c93210b61438758674b332449deb566899b3e32c59c4d2a95616c6ff9b3

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_binder_txns'
    ) THEN 1
    ELSE 0
  END as has_binder_table

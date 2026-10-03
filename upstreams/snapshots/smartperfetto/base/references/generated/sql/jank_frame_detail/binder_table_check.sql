-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: a0211e3d982714457a51437e411533797d8d6b214b85d9f67ce0d80ba4ad4c61

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_binder_txns'
    ) THEN 1
    ELSE 0
  END as has_binder_table

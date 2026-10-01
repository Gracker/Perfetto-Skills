-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 53ffd6d3f14eb46ea6d96882c52ecb04304522a845a61c66e81e1c627f33fc25

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_binder_txns'
    ) THEN 1
    ELSE 0
  END as has_binder_table

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 606707114b38750e9172c348cd727f2f00231b5a7b6ee521915247b5d62fe233

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_garbage_collection_events'
    ) THEN 1
    ELSE 0
  END as has_gc_table

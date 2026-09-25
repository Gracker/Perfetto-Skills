-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 960209f7b80fdced155eebd63d089f78ed033bbbb671d3a56279b95f8f92fc2b
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_garbage_collection_events'
    ) THEN 1
    ELSE 0
  END as has_gc_table

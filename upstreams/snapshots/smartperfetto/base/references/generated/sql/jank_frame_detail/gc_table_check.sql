-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 337f07b019184e56d2cbd55423b8bdf1d62ee20eb90821ab2d0791340050512f
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_garbage_collection_events'
    ) THEN 1
    ELSE 0
  END as has_gc_table

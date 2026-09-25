-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 601e2490169eb1b6b6c35ac9f2bc34e6c55075bfa03ef83af956a9e886ebf863
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_garbage_collection_events'
    ) THEN 1
    ELSE 0
  END as has_gc_table

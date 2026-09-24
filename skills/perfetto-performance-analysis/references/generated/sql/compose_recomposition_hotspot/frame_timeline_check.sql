-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 7f426a90804f6efc3d8ec7d94af37a4b4879abfa2ff4c95cf6360b70d16ca06a
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 7f426a90804f6efc3d8ec7d94af37a4b4879abfa2ff4c95cf6360b70d16ca06a
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

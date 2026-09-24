-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 192564e961761d7f0b09ad3f7c230a9b7dc62f5e8b965d6524c61fa8de1d6b66
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

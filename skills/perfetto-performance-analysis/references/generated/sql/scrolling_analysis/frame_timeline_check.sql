-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

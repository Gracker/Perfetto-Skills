-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 8f9a0954db22c1fcbcbb1d90da0bb15de24e08b37ba60f59c45fb99fa915eb4b
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

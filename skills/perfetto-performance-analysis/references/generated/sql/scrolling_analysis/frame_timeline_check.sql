-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: f0cb2ea3933bc319a9d98df1da466ba9e0fb54d39ba84dee41dfeff891fd009a
-- Source commit: d14f5cd1b769001e6f8bb35d3e7f90238af75884

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

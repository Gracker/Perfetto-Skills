-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 8016df273414d989f2aaa25e0e34647bbb695e925fcdcb07a400e74b9a806728

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

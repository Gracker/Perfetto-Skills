-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: b7ebca89bd8e31ada9de2d388e0e3cd9e257c8ef65e1c0e6862c167bc631da67
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

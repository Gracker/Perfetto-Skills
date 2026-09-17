-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 7c73e3893771fc262f7afad100bd5963d65ee2afe54b8bd139a0cf95e9c82eb8
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

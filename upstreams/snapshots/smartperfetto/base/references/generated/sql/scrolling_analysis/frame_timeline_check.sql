-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 917a301ba39a39244344d671654334dbea71801fdead788f5de43bd07d2f2865
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

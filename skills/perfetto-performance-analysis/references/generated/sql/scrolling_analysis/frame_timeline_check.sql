-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 898b631aafbdad1f8c7fabc5e2a741fa750cf701ec82b9810adfd3e687b94431
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

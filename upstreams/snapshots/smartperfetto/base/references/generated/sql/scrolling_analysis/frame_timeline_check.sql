-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 932de9b3d1c489168bad805861e11436f709ab3f63663add77ae3582aab383db
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

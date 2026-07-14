-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 2895ae93d263a1097b752875bc22c0e4521e6f96b6ad4feb319da03a76a0d59b
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

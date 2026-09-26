-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: ba394bc6522c94269f377cc156491c1e086d8b56f93d0b139390c08f76100b3b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

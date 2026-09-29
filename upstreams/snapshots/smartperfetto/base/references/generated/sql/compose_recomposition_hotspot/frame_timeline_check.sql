-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: ba394bc6522c94269f377cc156491c1e086d8b56f93d0b139390c08f76100b3b
-- Source commit: 12f4004d5cdc2aeac76d3afce68ef2e3e87d500f

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline

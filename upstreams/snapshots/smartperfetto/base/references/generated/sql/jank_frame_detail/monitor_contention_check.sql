-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: c7316828564ad4a4c71880cd7161b8aa58418ee7fd19812aa7a9d62357befce2

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'android_monitor_contention'
    ) THEN 1
    ELSE 0
  END as has_monitor_contention

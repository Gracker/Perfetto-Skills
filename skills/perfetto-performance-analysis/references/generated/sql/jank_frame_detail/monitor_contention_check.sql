-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: cc19de68a5c179e17af405bf32f9ca75f56af0c5a4ccf970ede72790c558942b
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'android_monitor_contention'
    ) THEN 1
    ELSE 0
  END as has_monitor_contention

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
-- Source SHA-256: 17b99628c5f63da669cd61bdbfc242a3c4c1081c73e8f12091bf24d3466e9fc2

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track WHERE type = 'cooling_device_counter'
  ) THEN 1 ELSE 0 END AS has_cdev_data,
  (SELECT COUNT(*) FROM counter_track WHERE type = 'cooling_device_counter') AS cdev_track_count

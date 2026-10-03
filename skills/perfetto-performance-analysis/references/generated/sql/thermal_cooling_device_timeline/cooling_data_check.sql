-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
-- Source SHA-256: 2bfbf5a93acfc357d547823fbb66c86dfb6194896e44f4c338d3a98f941c141b

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track WHERE type = 'cooling_device_counter'
  ) THEN 1 ELSE 0 END AS has_cdev_data,
  (SELECT COUNT(*) FROM counter_track WHERE type = 'cooling_device_counter') AS cdev_track_count

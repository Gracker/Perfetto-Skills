-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
-- Source SHA-256: 212c1203887256c5706a1e12c54ae6d163c0bb8647edd88afb0f73cc624cf16f
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track WHERE type = 'cooling_device_counter'
  ) THEN 1 ELSE 0 END AS has_cdev_data,
  (SELECT COUNT(*) FROM counter_track WHERE type = 'cooling_device_counter') AS cdev_track_count

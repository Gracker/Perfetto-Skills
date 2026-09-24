-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
-- Source SHA-256: 212c1203887256c5706a1e12c54ae6d163c0bb8647edd88afb0f73cc624cf16f
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track WHERE type = 'cooling_device_counter'
  ) THEN 1 ELSE 0 END AS has_cdev_data,
  (SELECT COUNT(*) FROM counter_track WHERE type = 'cooling_device_counter') AS cdev_track_count

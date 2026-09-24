-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_app_background_power_state.skill.yaml
-- Source SHA-256: 4ce3166f6ef8db3eca68f7a14cb6d6164abb3f15de2db690e545acc15ef4ff86
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

WITH facts AS (
  SELECT
    EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'android_app_wakelocks') AS has_wakelock_view,
    EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'android_battery_stats_event_slices') AS has_battery_stats_view,
    EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'android_standby_bucket') AS has_standby_view,
    EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'android_freezer_state_statsd') AS has_freezer_statsd_view,
    EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'android_freezer_events') AS has_freezer_events_table,
    EXISTS (
      SELECT 1 FROM slice AS s JOIN track AS t ON s.track_id = t.id
      WHERE t.name IN ('app_wakelock_events', 'battery_stats.longwake')
    ) AS has_wakelock_data,
    (SELECT COUNT(*) FROM slice WHERE name = 'app_standby_bucket_changed') AS standby_atom_count,
    (SELECT COUNT(*) FROM slice WHERE name = 'app_freeze_changed') AS freeze_atom_count,
    (SELECT COUNT(*) FROM slice WHERE name GLOB 'Freeze *:*') AS freezer_slice_count
)
SELECT
  CASE
    WHEN NOT has_wakelock_data THEN 'no_app_wakelock_data'
    WHEN has_wakelock_view THEN 'available'
    WHEN has_battery_stats_view THEN 'available_via_battery_stats'
    ELSE 'runtime_lacks_app_wakelocks'
  END AS wakelock_status,
  CASE
    WHEN standby_atom_count = 0 THEN 'no_standby_bucket_atoms'
    WHEN has_standby_view THEN 'available'
    ELSE 'runtime_lacks_android_standby_bucket'
  END AS standby_bucket_status,
  standby_atom_count,
  CASE
    WHEN freeze_atom_count > 0 AND has_freezer_statsd_view THEN 'available_statsd'
    WHEN freezer_slice_count > 0 AND has_freezer_events_table THEN 'available_slices'
    WHEN freeze_atom_count > 0 THEN 'runtime_lacks_freezer_statsd'
    ELSE 'no_freezer_data'
  END AS freezer_status,
  freeze_atom_count,
  freezer_slice_count
FROM facts

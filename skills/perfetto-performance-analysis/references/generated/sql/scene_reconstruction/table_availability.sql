-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='android_screen_state') THEN 1
    ELSE 0
  END AS has_screen_state,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='android_battery_stats_event_slices') THEN 1
    ELSE 0
  END AS has_battery_top,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='android_input_events') THEN 1
    ELSE 0
  END AS has_input_events,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='android_startups') THEN 1
    ELSE 0
  END AS has_startups,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='actual_frame_timeline_slice') THEN 1
    ELSE 0
  END AS has_frame_timeline,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='process_counter_track') THEN 1
    ELSE 0
  END AS has_process_counter_track,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='android_key_events') THEN 1
    ELSE 0
  END AS has_key_events,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='android_anrs') THEN 1
    ELSE 0
  END AS has_anrs

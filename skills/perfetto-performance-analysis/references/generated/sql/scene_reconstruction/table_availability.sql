-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 8832b9e9b6f0bb86a0676bcd50f367546a3406ef8111be90fe60511d26678d5b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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

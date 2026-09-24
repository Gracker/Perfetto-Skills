-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: b623b459c65d02509ded27617664691fec7c3b8848ac371759151eb7064d489a
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT
  printf('%d', start_ts) AS t_start,
  printf('%d', end_ts) AS t_end,
  printf('%d', start_ts) AS t_start_str,
  printf('%d', end_ts) AS t_end_str,
  ROUND((end_ts - start_ts) / 1e9, 2) AS duration_sec,
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
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name='actual_frame_timeline_slice') THEN 1
    ELSE 0
  END AS has_frame_timeline
FROM trace_bounds

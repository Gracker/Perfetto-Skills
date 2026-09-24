-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: fd6c633f728fed86747941747f63d55962479f3073fb5dada8da2116d5ec350b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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

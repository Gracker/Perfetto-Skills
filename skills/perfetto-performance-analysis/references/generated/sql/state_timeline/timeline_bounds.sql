-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: e3ba12b4a53d3c90d152f942c7f910e4108218ef5da2c56c0e19561009686fc2
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  MIN(ts) AS t_start,
  MAX(ts) AS t_end,
  printf('%d', MIN(ts)) AS t_start_str,
  printf('%d', MAX(ts)) AS t_end_str,
  ROUND((MAX(ts) - MIN(ts)) / 1e9, 2) AS duration_sec,
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
FROM (
  SELECT ts FROM slice WHERE dur > 0
  UNION ALL
  SELECT ts FROM counter WHERE value IS NOT NULL
)

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: b623b459c65d02509ded27617664691fec7c3b8848ac371759151eb7064d489a
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

-- Summary: aggregate stats per lane
-- This step always succeeds (uses slice table which always exists)
WITH lane_bounds AS (
  SELECT ROUND((end_ts - start_ts) / 1e9, 2) AS duration_sec FROM trace_bounds
),
table_status AS (
  SELECT
    CASE WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_screen_state') THEN 'available' ELSE 'table_missing' END AS device_status,
    CASE
      WHEN NOT EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_input_events') THEN 'table_missing'
      WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='actual_frame_timeline_slice') THEN 'partial'
      ELSE 'partial'
    END AS input_status,
    CASE WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_battery_stats_event_slices') THEN 'available' ELSE 'table_missing' END AS app_status,
    'available' AS system_status
)
SELECT 'device' AS lane, 0 AS segment_count, (SELECT duration_sec FROM lane_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT device_status FROM table_status) AS source_status
UNION ALL
SELECT 'input' AS lane, 0 AS segment_count, (SELECT duration_sec FROM lane_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT input_status FROM table_status) AS source_status
UNION ALL
SELECT 'app' AS lane, 0 AS segment_count, (SELECT duration_sec FROM lane_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT app_status FROM table_status) AS source_status
UNION ALL
SELECT 'system' AS lane, 0 AS segment_count, (SELECT duration_sec FROM lane_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT system_status FROM table_status) AS source_status

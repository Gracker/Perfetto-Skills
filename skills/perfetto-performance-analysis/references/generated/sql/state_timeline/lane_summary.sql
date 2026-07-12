-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: e3ba12b4a53d3c90d152f942c7f910e4108218ef5da2c56c0e19561009686fc2
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

-- Summary: aggregate stats per lane
-- This step always succeeds (uses slice table which always exists)
WITH trace_bounds AS (
  SELECT
    MIN(ts) AS t_start,
    MAX(ts) AS t_end,
    ROUND((MAX(ts) - MIN(ts)) / 1e9, 2) AS duration_sec
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
table_status AS (
  SELECT
    CASE WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_screen_state') THEN 'available' ELSE 'table_missing' END AS device_status,
    CASE
      WHEN NOT EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_input_events') THEN 'table_missing'
      WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='actual_frame_timeline_slice') THEN 'available_frame_based'
      ELSE 'available_heuristic'
    END AS input_status,
    CASE WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_battery_stats_event_slices') THEN 'available' ELSE 'table_missing' END AS app_status,
    'available' AS system_status
)
SELECT 'device' AS lane, 0 AS segment_count, (SELECT duration_sec FROM trace_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT device_status FROM table_status) AS source_status
UNION ALL
SELECT 'input' AS lane, 0 AS segment_count, (SELECT duration_sec FROM trace_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT input_status FROM table_status) AS source_status
UNION ALL
SELECT 'app' AS lane, 0 AS segment_count, (SELECT duration_sec FROM trace_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT app_status FROM table_status) AS source_status
UNION ALL
SELECT 'system' AS lane, 0 AS segment_count, (SELECT duration_sec FROM trace_bounds) AS total_dur_sec, '-' AS dominant_state, (SELECT system_status FROM table_status) AS source_status

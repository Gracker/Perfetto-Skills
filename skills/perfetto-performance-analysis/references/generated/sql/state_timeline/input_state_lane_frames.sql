-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: 847df75d4dff0db6d9e8a10b5d5654d248cc898fde909ce265075dfb85209401
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH trace_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
-- Gesture event extraction from MOTION events
gesture_events AS (
  SELECT
    read_time AS ts,
    event_action,
    CASE WHEN event_action IN ('DOWN', 'POINTER_DOWN') THEN 1 ELSE 0 END AS is_start
  FROM android_input_events
  WHERE event_type = 'MOTION'
),
-- Group events into gestures (each DOWN starts a new gesture)
gesture_groups AS (
  SELECT ts, event_action,
    SUM(is_start) OVER (ORDER BY ts) AS gesture_id
  FROM gesture_events
),
-- Aggregate per gesture
gesture_summary AS (
  SELECT
    gesture_id,
    MIN(ts) AS start_ts,
    MAX(ts) AS end_ts,
    MAX(ts) - MIN(ts) AS dur,
    COUNT(*) AS event_count,
    COUNT(CASE WHEN event_action = 'MOVE' THEN 1 END) AS move_count,
    MAX(CASE WHEN event_action IN ('UP', 'POINTER_UP') THEN ts END) AS up_ts,
    MAX(CASE WHEN event_action = 'CANCEL' THEN 1 ELSE 0 END) AS was_cancelled
  FROM gesture_groups
  WHERE gesture_id > 0
  GROUP BY gesture_id
  HAVING event_count >= 2
),
-- Classify each gesture into a state
classified AS (
  SELECT
    gesture_id,
    start_ts,
    COALESCE(up_ts, end_ts) AS end_ts,
    CASE
      WHEN was_cancelled = 1 THEN 'TAP'
      WHEN move_count >= 3 THEN 'SCROLL_DRAG'
      WHEN dur >= 300000000 AND move_count <= 2 THEN 'LONG_PRESS'
      ELSE 'TAP'
    END AS state,
    move_count,
    was_cancelled
  FROM gesture_summary
),
-- App frames from actual_frame_timeline_slice (for FLING termination)
frame_apps AS (
  SELECT
    a.ts,
    a.dur,
    a.ts + a.dur AS end_ts,
    COALESCE(
      NULLIF(p.name, ''),
      CASE
        WHEN a.layer_name IS NOT NULL AND instr(a.layer_name, '/') > 1
        THEN substr(a.layer_name, 1, instr(a.layer_name, '/') - 1)
        ELSE NULL
      END
    ) AS app_package
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON p.upid = a.upid
  WHERE a.dur > 0
    AND a.surface_frame_token IS NOT NULL
),
-- FLING windows: from SCROLL_DRAG UP to next DOWN (max 3s scan window)
fling_windows AS (
  SELECT
    c.gesture_id,
    c.end_ts AS fling_start,
    MIN(
      COALESCE(
        (SELECT c2.start_ts FROM classified c2
         WHERE c2.start_ts > c.end_ts
         ORDER BY c2.start_ts LIMIT 1),
        c.end_ts + 3000000000
      ),
      c.end_ts + 3000000000
    ) AS fling_window_end
  FROM classified c
  WHERE c.state = 'SCROLL_DRAG'
    AND c.move_count >= 4
    AND c.end_ts < (SELECT t_end FROM trace_bounds)
),
-- Match frames in fling window (exclude system processes)
fling_with_frames AS (
  SELECT
    w.gesture_id,
    w.fling_start,
    w.fling_window_end,
    MAX(f.end_ts) AS last_frame_end,
    COUNT(f.ts) AS frame_count
  FROM fling_windows w
  LEFT JOIN frame_apps f
    ON f.ts >= w.fling_start
   AND f.ts < w.fling_window_end
   AND f.app_package IS NOT NULL
   AND f.app_package != ''
   AND f.app_package NOT GLOB 'surfaceflinger*'
   AND f.app_package NOT GLOB 'system_server*'
   AND f.app_package NOT GLOB 'com.android.systemui*'
  GROUP BY w.gesture_id, w.fling_start, w.fling_window_end
),
-- Resolve FLING end: last frame end if frames found, else conservative default
fling_candidates AS (
  SELECT
    fling_start AS start_ts,
    CASE
      WHEN frame_count >= 1 AND last_frame_end > fling_start + 80000000
        THEN MIN(last_frame_end, fling_window_end)
      ELSE MIN(fling_start + 300000000, fling_window_end)
    END AS end_ts,
    'FLING' AS state
  FROM fling_with_frames
),
-- Combine gestures + fling
input_events AS (
  SELECT start_ts, end_ts, state FROM classified
  UNION ALL
  SELECT start_ts, end_ts, state FROM fling_candidates
  WHERE end_ts > start_ts + 80000000
),
ordered AS (
  SELECT start_ts, end_ts, state,
    ROW_NUMBER() OVER (ORDER BY start_ts) AS rn
  FROM input_events
  ORDER BY start_ts
),
-- Fill gaps with IDLE
idle_gaps AS (
  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'IDLE' AS state
  WHERE NOT EXISTS (SELECT 1 FROM ordered)

  UNION ALL

  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT MIN(start_ts) FROM ordered) AS end_ts,
    'IDLE' AS state
  WHERE EXISTS (SELECT 1 FROM ordered)
    AND (SELECT MIN(start_ts) FROM ordered) > (SELECT t_start FROM trace_bounds)

  UNION ALL

  SELECT
    o1.end_ts AS start_ts,
    o2.start_ts AS end_ts,
    'IDLE' AS state
  FROM ordered o1
  JOIN ordered o2 ON o2.rn = o1.rn + 1
  WHERE o2.start_ts > o1.end_ts

  UNION ALL

  SELECT
    (SELECT MAX(end_ts) FROM ordered) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'IDLE' AS state
  WHERE EXISTS (SELECT 1 FROM ordered)
    AND (SELECT MAX(end_ts) FROM ordered) < (SELECT t_end FROM trace_bounds)
),
all_raw AS (
  SELECT start_ts, end_ts, state FROM ordered
  UNION ALL
  SELECT start_ts, end_ts, state FROM idle_gaps
  WHERE end_ts > start_ts
)
SELECT
  'input' AS lane,
  state,
  CASE state
    WHEN 'IDLE' THEN '空闲'
    WHEN 'TAP' THEN '点击'
    WHEN 'LONG_PRESS' THEN '长按'
    WHEN 'SCROLL_DRAG' THEN '按压滑动'
    WHEN 'FLING' THEN '惯性滑动'
    ELSE state
  END AS state_label,
  printf('%d', start_ts) AS start_ts,
  printf('%d', end_ts) AS end_ts,
  end_ts - start_ts AS dur_ns,
  CAST((end_ts - start_ts) / 1000000 AS INT) AS dur_ms,
  'available_frame_based' AS source_status
FROM all_raw
WHERE end_ts > start_ts
ORDER BY start_ts
LIMIT 1000

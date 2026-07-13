-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH all_events AS (
  -- 屏幕状态
  SELECT
    CAST(ts AS INTEGER) AS ts,
    CAST(dur AS INTEGER) AS dur,
    event,
    'screen' AS category,
    1 AS priority
  FROM (
    SELECT
      printf('%d', ts) AS ts,
      printf('%d', dur) AS dur,
      CASE screen_state
        WHEN 1 THEN '屏幕熄灭'
        WHEN 2 THEN '屏幕点亮'
        WHEN 3 THEN '屏幕休眠'
        ELSE '屏幕状态 ' || screen_state
      END AS event
    FROM android_screen_state
    WHERE dur > 0
    LIMIT 50
  )

  UNION ALL

  -- Top App 切换
  SELECT
    CAST(ts AS INTEGER) AS ts,
    CAST(dur AS INTEGER) AS dur,
    event,
    'app_switch' AS category,
    2 AS priority
  FROM (
    SELECT
      printf('%d', ts) AS ts,
      printf('%d', safe_dur) AS dur,
      '切换到 ' || REPLACE(REPLACE(str_value, 'com.', ''), 'android.', '') AS event
    FROM android_battery_stats_event_slices
    WHERE track_name = 'battery_stats.top' AND safe_dur > 100000000
    LIMIT 50
  )

  UNION ALL

  -- 用户手势
  SELECT
    ts, dur, event, 'gesture' AS category, 3 AS priority
  FROM (
    WITH gesture_events AS (
      SELECT
        read_time AS ts,
        event_action,
        process_name,
        CASE WHEN event_action = 'DOWN' THEN 1 ELSE 0 END AS is_start
      FROM android_input_events
      WHERE event_type = 'MOTION'
    ),
    gesture_groups AS (
      SELECT ts, event_action, process_name,
             SUM(is_start) OVER (ORDER BY ts) AS gesture_id
      FROM gesture_events
    ),
    gestures AS (
      SELECT
        gesture_id,
        MIN(ts) AS ts,
        MAX(ts) - MIN(ts) AS dur,
        COUNT(*) AS event_count,
        COUNT(CASE WHEN event_action = 'MOVE' THEN 1 END) AS move_count,
        MAX(process_name) AS app
      FROM gesture_groups
      WHERE gesture_id > 0
      GROUP BY gesture_id
      HAVING COUNT(*) >= 2
    )
    SELECT
      CAST(ts AS INTEGER) AS ts,
      CAST(dur AS INTEGER) AS dur,
      CASE
        WHEN move_count >= 3 THEN '滑动 (' || move_count || '次移动)'
        WHEN dur > 500000000 AND move_count <= 2 THEN '长按'
        ELSE '点击'
      END ||
      CASE
        WHEN app IS NOT NULL AND app != ''
        THEN ' [' || REPLACE(REPLACE(app, 'com.', ''), 'android.', '') || ']'
        ELSE ''
      END AS event
    FROM gestures
    LIMIT 100
  )

  UNION ALL

  -- App 启动
  SELECT
    CAST(ts AS INTEGER) AS ts,
    CAST(dur AS INTEGER) AS dur,
    event,
    'app_launch' AS category,
    4 AS priority
  FROM (
    SELECT
      printf('%d', ts) AS ts,
      printf('%d', dur) AS dur,
      CASE startup_type
        WHEN 'cold' THEN '冷启动'
        WHEN 'warm' THEN '温启动'
        WHEN 'hot' THEN '热启动'
        ELSE '启动'
      END || ' ' ||
      REPLACE(REPLACE(package, 'com.', ''), 'android.', '') ||
      ' [' || CAST(dur / 1000000 AS INT) || 'ms]' AS event
    FROM android_startups
    WHERE dur > 0
    LIMIT 30
  )

  UNION ALL

  -- 掉帧事件
  SELECT
    CAST(ts AS INTEGER) AS ts,
    CAST(dur AS INTEGER) AS dur,
    event,
    'performance' AS category,
    5 AS priority
  FROM (
    SELECT
      printf('%d', ts) AS ts,
      printf('%d', dur) AS dur,
      CASE
        WHEN jank_type LIKE '%App Deadline%' OR jank_type = 'Self Jank' THEN 'App掉帧'
        WHEN jank_type LIKE '%SurfaceFlinger%' THEN '合成器掉帧'
        ELSE '掉帧'
      END || ' [' || CAST(dur / 1000000 AS INT) || 'ms]' AS event
    FROM actual_frame_timeline_slice
    WHERE jank_type IS NOT NULL AND jank_type != 'None' AND jank_type != ''
    LIMIT 50
  )
),
time_range AS (
  SELECT MIN(ts) AS start_ts FROM all_events
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur,
  ROUND((ts - (SELECT start_ts FROM time_range)) / 1e9, 2) AS time_offset_sec,
  event,
  category,
  priority
FROM all_events
ORDER BY ts, priority
LIMIT 300

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

-- 此 step 检测滑动开始的精确时刻
-- 原理：当手指 DOWN 后连续出现 2 个 MOVE 事件时，认为滑动启动
WITH RECURSIVE input_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='android_input_events'
  )
),
motion_base AS (
  SELECT
    event_action,
    read_time AS ts,
    process_name,
    SUM(CASE WHEN event_action = 'DOWN' THEN 1 ELSE 0 END)
      OVER (ORDER BY read_time) AS gesture_id
  FROM android_input_events
  WHERE event_type = 'MOTION'
    AND event_action IN ('DOWN', 'MOVE', 'UP')
),
motion_with_seq AS (
  SELECT
    event_action,
    ts,
    process_name,
    gesture_id,
    SUM(CASE WHEN event_action = 'MOVE' THEN 1 ELSE 0 END)
      OVER (
        PARTITION BY gesture_id
        ORDER BY ts
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS move_seq
  FROM motion_base
),
scroll_starts AS (
  SELECT
    MIN(ts) AS scroll_start_ts,
    gesture_id,
    MAX(process_name) AS app
  FROM motion_with_seq
  WHERE event_action = 'MOVE'
    AND move_seq >= 2
    AND gesture_id > 0
  GROUP BY gesture_id
)
SELECT
  printf('%d', scroll_start_ts) AS ts,
  '0' AS dur,
  '滑动启动' ||
  CASE
    WHEN app IS NOT NULL AND app != ''
    THEN ' [' || REPLACE(REPLACE(app, 'com.', ''), 'android.', '') || ']'
    ELSE ''
  END AS event,
  gesture_id,
  app AS app_package,
  'scroll_start' AS category,
  '💡 此时刻手指已移动足够距离，系统开始响应滑动' AS explanation
FROM scroll_starts
ORDER BY scroll_start_ts
LIMIT 100

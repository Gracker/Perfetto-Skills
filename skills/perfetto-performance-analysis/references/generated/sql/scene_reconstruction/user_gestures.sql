-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH RECURSIVE input_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='android_input_events'
  )
),
startup_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='android_startups'
  )
),
frame_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='actual_frame_timeline_slice'
  )
),
startup_spans AS (
  SELECT
    ts AS start_ts,
    ts + dur AS end_ts,
    package AS app_package
  FROM android_startups
  WHERE dur > 0
),
frame_apps AS (
  SELECT
    a.ts,
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
gesture_events AS (
  SELECT
    read_time AS ts,
    event_action,
    process_name,
    CASE WHEN event_action = 'DOWN' THEN 1 ELSE 0 END AS is_start
  FROM android_input_events
  WHERE event_type = 'MOTION'
    AND process_name NOT IN ('system_server', '/system/bin/inputflinger')
    AND process_name NOT GLOB 'com.android.systemui*'
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
    MAX(ts) AS end_ts,
    MAX(ts) - MIN(ts) AS dur,
    MAX(CASE WHEN event_action = 'UP' THEN ts END) AS up_ts,
    COUNT(*) AS event_count,
    COUNT(CASE WHEN event_action = 'MOVE' THEN 1 END) AS move_count,
    MAX(process_name) AS raw_process_name
  FROM gesture_groups
  WHERE gesture_id > 0
  GROUP BY gesture_id
),
gesture_with_app AS (
  SELECT
    g.*,
    (SELECT MIN(g2.ts) FROM gestures g2 WHERE g2.ts > g.ts) AS next_gesture_ts,
    CASE
      WHEN g.raw_process_name GLOB 'com.*'
        OR g.raw_process_name GLOB 'org.*'
        OR g.raw_process_name GLOB 'io.*'
        OR g.raw_process_name GLOB 'net.*'
      THEN g.raw_process_name
      ELSE COALESCE(
        (SELECT f.app_package
         FROM frame_apps f
         WHERE f.app_package IS NOT NULL
           AND f.app_package != ''
           AND f.app_package NOT GLOB 'surfaceflinger*'
           AND f.app_package NOT GLOB 'system_server*'
           AND f.app_package NOT GLOB 'com.android.systemui*'
           AND f.ts >= g.ts - 300000000
           AND f.end_ts <= g.end_ts + 800000000
         GROUP BY f.app_package
         ORDER BY COUNT(*) DESC
         LIMIT 1),
        (SELECT s.app_package
         FROM startup_spans s
         WHERE g.ts BETWEEN s.start_ts AND s.end_ts
         ORDER BY s.start_ts DESC
         LIMIT 1),
        g.raw_process_name
      )
    END AS app_package
  FROM gestures g
),
gesture_with_window AS (
  SELECT
    g.*,
    CASE
      WHEN g.up_ts IS NOT NULL THEN
        MIN(
          COALESCE(g.next_gesture_ts, g.up_ts + 3000000000),
          g.up_ts + 3000000000
        )
      ELSE g.end_ts
    END AS scroll_window_end
  FROM gesture_with_app g
),
gesture_with_duration AS (
  SELECT
    g.*,
    CASE
      -- For scroll gestures, extend duration to the last rendered frame after UP
      -- (bounded by next gesture or 3s) to match user-perceived scroll length.
      WHEN g.move_count >= 3 AND g.up_ts IS NOT NULL THEN
        MAX(
          g.dur,
          COALESCE(
            (SELECT MAX(f.end_ts)
             FROM frame_apps f
             WHERE f.ts >= g.up_ts
               AND f.ts < g.scroll_window_end
               AND (
                 g.app_package IS NULL
                 OR g.app_package = ''
                 OR f.app_package = g.app_package
               )),
            (SELECT MAX(f.end_ts)
             FROM frame_apps f
             WHERE f.ts >= g.up_ts
               AND f.ts < g.scroll_window_end),
            MIN(
              COALESCE(g.next_gesture_ts, g.up_ts + 1800000000),
              g.up_ts + 1800000000
            )
          ) - g.ts
        )
      ELSE g.dur
    END AS scene_dur
  FROM gesture_with_window g
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', scene_dur) AS dur,
  CASE
    WHEN move_count >= 3 THEN '滑动 (' || move_count || '次移动, ' || CAST(scene_dur / 1000000 AS INT) || 'ms)'
    WHEN dur > 500000000 AND move_count <= 2 THEN '长按 (' || CAST(dur / 1000000 AS INT) || 'ms)'
    ELSE '点击'
  END ||
  CASE
    WHEN app_package IS NOT NULL AND app_package != ''
    THEN ' [' || REPLACE(REPLACE(app_package, 'com.', ''), 'android.', '') || ']'
    ELSE ''
  END AS event,
  CASE
    WHEN move_count >= 3 THEN 'scroll'
    WHEN dur > 500000000 AND move_count <= 2 THEN 'long_press'
    ELSE 'tap'
  END AS gesture_type,
  CASE
    WHEN move_count >= 10 THEN '高'
    WHEN move_count >= 5 THEN '中'
    WHEN move_count >= 3 THEN '低'
    ELSE '高'
  END AS confidence,
  move_count,
  app_package,
  'gesture' AS category
FROM gesture_with_duration
WHERE event_count >= 2
ORDER BY ts
LIMIT 200

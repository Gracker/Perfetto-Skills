-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH time_bounds AS (
  SELECT MIN(ts) AS t_start
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
-- Screen state removed: now shown in dedicated Device State lane (state_timeline skill)
-- ========== 数据源 1: App 启动 (reclassify: bindApplication → cold) ==========
launch_type_validated AS (
  SELECT
    s.ts, s.dur, s.package, s.startup_id,
    CASE
      WHEN EXISTS (
        SELECT 1 FROM android_startup_threads st
        JOIN thread_track tt ON tt.utid = st.utid
        JOIN slice sl ON sl.track_id = tt.id
        WHERE st.startup_id = s.startup_id
          AND st.is_main_thread = 1
          AND sl.name = 'bindApplication'
          AND sl.ts + sl.dur > st.ts AND sl.ts < st.ts + st.dur
      ) THEN 'cold'
      ELSE s.startup_type
    END AS startup_type
  FROM android_startups s
  WHERE s.dur > 0
    AND EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_startups')
),
launch_ev AS (
  SELECT
    s.ts,
    s.dur,
    CASE s.startup_type
      WHEN 'cold' THEN '冷启动'
      WHEN 'warm' THEN '温启动'
      WHEN 'hot' THEN '热启动'
      ELSE '启动'
    END || ' ' ||
    REPLACE(REPLACE(s.package, 'com.', ''), 'android.', '') ||
    ' [' || CAST(s.dur / 1000000 AS INT) || 'ms]' AS event,
    CASE s.startup_type
      WHEN 'cold' THEN 'cold_start'
      WHEN 'warm' THEN 'warm_start'
      WHEN 'hot' THEN 'hot_start'
      ELSE 'cold_start'
    END AS event_type,
    s.package AS app_package,
    'app_launch' AS category,
    2 AS priority
  FROM launch_type_validated s
  LIMIT 30
),
-- ========== 数据源 3: 用户手势 (tap/scroll/long_press) ==========
gesture_base AS (
  SELECT
    read_time AS ts, event_action, process_name,
    SUM(CASE WHEN event_action = 'DOWN' THEN 1 ELSE 0 END) OVER (ORDER BY read_time) AS gid
  FROM android_input_events
  WHERE event_type = 'MOTION'
    AND process_name NOT IN ('system_server', '/system/bin/inputflinger')
    AND process_name NOT GLOB 'com.android.systemui*'
    AND EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_input_events')
),
gesture_agg AS (
  SELECT
    gid,
    MIN(ts) AS ts,
    MAX(ts) - MIN(ts) AS dur,
    COUNT(*) AS event_count,
    COUNT(CASE WHEN event_action = 'MOVE' THEN 1 END) AS move_count,
    MAX(process_name) AS app
  FROM gesture_base
  WHERE gid > 0
  GROUP BY gid
  HAVING COUNT(*) >= 2
),
gesture_ev AS (
  SELECT
    ts,
    dur,
    CASE
      WHEN move_count >= 3 THEN '滑动 (' || move_count || '次移动, ' || CAST(dur / 1000000 AS INT) || 'ms)'
      WHEN dur > 500000000 AND move_count <= 2 THEN '长按 (' || CAST(dur / 1000000 AS INT) || 'ms)'
      ELSE '点击'
    END ||
    CASE
      WHEN app IS NOT NULL AND app != ''
      THEN ' [' || REPLACE(REPLACE(app, 'com.', ''), 'android.', '') || ']'
      ELSE ''
    END AS event,
    CASE
      WHEN move_count >= 3 THEN 'scroll'
      WHEN dur > 500000000 AND move_count <= 2 THEN 'long_press'
      ELSE 'tap'
    END AS event_type,
    CASE
      WHEN app IS NOT NULL AND app != '' THEN app
      ELSE NULL
    END AS app_package,
    'gesture' AS category,
    3 AS priority
  FROM gesture_agg
  LIMIT 60
),
-- ========== 数据源 4: Top App 切换 ==========
topapp_ev AS (
  SELECT
    ts,
    safe_dur AS dur,
    '切换到 ' || REPLACE(REPLACE(str_value, 'com.', ''), 'android.', '') AS event,
    CASE
      WHEN LOWER(str_value) LIKE '%launcher%' OR LOWER(str_value) LIKE '%miui.home%'
        OR LOWER(str_value) LIKE '%trebuchet%' OR LOWER(str_value) LIKE '%nexuslauncher%'
        OR LOWER(str_value) LIKE '%lawnchair%' OR LOWER(str_value) LIKE '%.home%'
        THEN 'home_screen'
      ELSE 'app_foreground'
    END AS event_type,
    str_value AS app_package,
    'app_switch' AS category,
    4 AS priority
  FROM android_battery_stats_event_slices
  WHERE track_name = 'battery_stats.top'
    AND safe_dur > 100000000
    AND EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_battery_stats_event_slices')
  LIMIT 30
),
-- ========== 数据源 5: 系统事件 (quality-gated) ==========
system_ev AS (
  SELECT
    ts,
    dur,
    CASE
      WHEN LOWER(name) LIKE '%keyguard%dismiss%'
        OR LOWER(name) LIKE '%keyguard%unlock%'
        OR LOWER(name) LIKE '%lockscreen%unlock%'
        OR LOWER(name) LIKE '%unlock%screen%'
        THEN '解锁屏幕'
      WHEN LOWER(name) LIKE '%notificationpanel%expand%' THEN '下拉通知栏'
      WHEN LOWER(name) LIKE '%notificationpanel%collapse%' THEN '收起通知栏'
      WHEN LOWER(name) LIKE '%splitscreen%' THEN '分屏操作'
      WHEN LOWER(name) LIKE '%enterpictureinpicture%' THEN '进入画中画'
      WHEN LOWER(name) LIKE '%exitpictureinpicture%' THEN '退出画中画'
      ELSE NULL
    END AS event,
    CASE
      WHEN LOWER(name) LIKE '%keyguard%' OR LOWER(name) LIKE '%lockscreen%'
        OR LOWER(name) LIKE '%unlock%screen%' THEN 'screen_unlock'
      WHEN LOWER(name) LIKE '%notificationpanel%' THEN 'notification'
      WHEN LOWER(name) LIKE '%splitscreen%' THEN 'split_screen'
      WHEN LOWER(name) LIKE '%pictureinpicture%' THEN 'pip'
      ELSE 'system'
    END AS event_type,
    NULL AS app_package,
    'system' AS category,
    2 AS priority
  FROM slice
  WHERE (
      (LOWER(name) LIKE '%keyguard%dismiss%' AND dur > 100000000)
      OR (LOWER(name) LIKE '%keyguard%unlock%' AND dur > 100000000)
      OR (LOWER(name) LIKE '%lockscreen%unlock%' AND dur > 100000000)
      OR (LOWER(name) LIKE '%unlock%screen%' AND dur > 100000000)
      OR (LOWER(name) LIKE '%notificationpanel%expand%' AND dur > 200000000)
      OR (LOWER(name) LIKE '%notificationpanel%collapse%' AND dur > 200000000)
      OR (LOWER(name) LIKE '%splitscreen%' AND dur > 500000000)
      OR (LOWER(name) LIKE '%enterpictureinpicture%' AND dur > 300000000)
      OR (LOWER(name) LIKE '%exitpictureinpicture%' AND dur > 300000000)
    )
    AND LOWER(name) NOT LIKE '%unlockcanvasandpost%'
    AND LOWER(name) NOT LIKE '%unlockandpost%'
    AND LOWER(name) != 'unlock'
  LIMIT 20
),
-- ========== 数据源 6: Idle 空闲 ==========
idle_ev AS (
  SELECT
    ts,
    gap_ns AS dur,
    '空闲 (' || CAST(gap_ns / 1000000 AS INT) || 'ms)' AS event,
    'idle' AS event_type,
    NULL AS app_package,
    'idle' AS category,
    5 AS priority
  FROM (
    SELECT
      ts,
      LEAD(ts) OVER (ORDER BY ts) AS next_ts,
      LEAD(ts) OVER (ORDER BY ts) - ts AS gap_ns
    FROM (
      SELECT read_time AS ts FROM android_input_events
      WHERE event_type = 'MOTION' AND event_action = 'DOWN'
        AND process_name NOT IN ('system_server', '/system/bin/inputflinger')
        AND process_name NOT GLOB 'com.android.systemui*'
        AND EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_input_events')
      UNION ALL
      SELECT ts FROM android_startups WHERE dur > 0
        AND EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_startups')
    )
  )
  WHERE gap_ns >= 800000000
  LIMIT 30
),
-- ========== 数据源 7: 导航按键 + 手势导航 ==========
nav_key_ev AS (
  SELECT ts, dur, event, key_name AS event_type, NULL AS app_package,
         'navigation_key' AS category, 2 AS priority
  FROM (
    -- Source A: android_key_events (三键导航)
    SELECT printf('%d', d.ts) AS ts, printf('%d', COALESCE(u.up_ts - d.ts, 0)) AS dur,
      CASE d.key_code WHEN 4 THEN '返回键' WHEN 3 THEN 'Home键' WHEN 187 THEN '最近任务键' END AS event,
      CASE d.key_code WHEN 4 THEN 'back_key' WHEN 3 THEN 'home_key' WHEN 187 THEN 'recents_key' END AS key_name
    FROM (SELECT ts, key_code, ROW_NUMBER() OVER (PARTITION BY key_code ORDER BY ts) AS rn
          FROM android_key_events WHERE action = 0 AND key_code IN (3,4,187)) d
    LEFT JOIN (SELECT ts AS up_ts, key_code, ROW_NUMBER() OVER (PARTITION BY key_code ORDER BY ts) AS rn
               FROM android_key_events WHERE action = 1 AND key_code IN (3,4,187)) u
      ON u.key_code = d.key_code AND u.rn = d.rn AND u.up_ts >= d.ts
    WHERE EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_key_events')
    UNION ALL
    -- Source B: gesture navigation slices (手势导航)
    SELECT printf('%d', s.ts) AS ts, printf('%d', s.dur) AS dur,
      CASE
        WHEN s.name GLOB '*BackGesture*' OR s.name GLOB '*onBackGesture*' OR s.name GLOB '*BackPanel*' THEN '返回手势'
        WHEN s.name GLOB '*SwipeToHome*' OR s.name GLOB '*goToHome*'
          OR s.name GLOB '*launcher*goHome*' THEN 'Home手势'
        WHEN s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*' THEN '最近任务手势'
      END AS event,
      CASE
        WHEN s.name GLOB '*BackGesture*' OR s.name GLOB '*onBackGesture*' OR s.name GLOB '*BackPanel*' THEN 'back_key'
        WHEN s.name GLOB '*SwipeToHome*' OR s.name GLOB '*goToHome*'
          OR s.name GLOB '*launcher*goHome*' THEN 'home_key'
        WHEN s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*' THEN 'recents_key'
      END AS key_name
    FROM slice s
    JOIN thread_track tt ON s.track_id = tt.id JOIN thread t ON tt.utid = t.utid JOIN process p ON t.upid = p.upid
    WHERE (p.name GLOB 'com.android.systemui*' OR p.name GLOB '*launcher*')
      AND s.dur > 10000000
      AND (s.name GLOB '*BackGesture*' OR s.name GLOB '*onBackGesture*' OR s.name GLOB '*BackPanel*'
           OR s.name GLOB '*SwipeToHome*' OR s.name GLOB '*goToHome*' OR s.name GLOB '*launcher*goHome*'
           OR s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*')
  ) sub
  WHERE event IS NOT NULL
  LIMIT 60
),
-- ========== 数据源 8: ANR ==========
anr_ev AS (
  SELECT
    printf('%d', ts - CAST(COALESCE(anr_dur_ms, default_anr_dur_ms, 5000) AS INTEGER) * 1000000) AS ts,
    printf('%d', CAST(COALESCE(anr_dur_ms, default_anr_dur_ms, 5000) AS INTEGER) * 1000000) AS dur,
    'ANR: ' || REPLACE(REPLACE(process_name, 'com.', ''), 'android.', '') ||
      ' (' || COALESCE(anr_type, 'unknown') || ')' AS event,
    'anr' AS event_type,
    process_name AS app_package,
    'anr' AS category,
    1 AS priority
  FROM android_anrs
  WHERE EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_anrs')
  LIMIT 20
),
-- ========== 数据源 9: 输入法 ==========
ime_ev AS (
  SELECT printf('%d', s.ts) AS ts, printf('%d', s.dur) AS dur,
    CASE WHEN s.name GLOB '*show*' THEN '键盘弹出 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
         ELSE '键盘收起 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
    END AS event,
    CASE WHEN s.name GLOB '*show*' THEN 'ime_show' ELSE 'ime_hide' END AS event_type,
    NULL AS app_package, 'ime' AS category, 4 AS priority
  FROM slice s
  WHERE s.dur > 5000000
    AND (s.name GLOB '*showSoftInput*' OR s.name GLOB '*hideSoftInput*'
         OR s.name GLOB '*InputMethodService*show*' OR s.name GLOB '*InputMethodService*hide*'
         OR s.name GLOB '*InputMethodManager*show*' OR s.name GLOB '*InputMethodManager*hide*')
  LIMIT 30
),
-- ========== 数据源 10: 窗口转场 ==========
win_trans_ev AS (
  SELECT printf('%d', s.ts) AS ts, printf('%d', s.dur) AS dur,
    CASE
      WHEN s.name GLOB '*openAnimation*' THEN '窗口打开'
      WHEN s.name GLOB '*closeAnimation*' THEN '窗口关闭'
      WHEN s.name GLOB '*Shell transition*' THEN 'Shell转场'
      ELSE '窗口转场'
    END || ' [' || CAST(s.dur / 1000000 AS INT) || 'ms]' AS event,
    'window_transition' AS event_type,
    NULL AS app_package, 'window_transition' AS category, 4 AS priority
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id JOIN thread t ON tt.utid = t.utid JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'system_server' OR p.name GLOB 'com.android.wm.shell*')
    AND s.dur > 50000000
    AND (s.name GLOB '*AppTransition*' OR s.name GLOB '*openAnimation*'
         OR s.name GLOB '*closeAnimation*' OR s.name GLOB '*Shell transition*'
         OR s.name GLOB '*startingWindow*')
  LIMIT 30
),
-- ========== 合并 + 过滤 + 排序 ==========
all_events AS (
  SELECT ts, dur, event, event_type, app_package, category, priority FROM launch_ev
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM gesture_ev
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM topapp_ev
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM system_ev WHERE event IS NOT NULL
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM idle_ev
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM nav_key_ev
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM anr_ev
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM ime_ev
  UNION ALL
  SELECT ts, dur, event, event_type, app_package, category, priority FROM win_trans_ev
),
-- ========== 格式化输出 ==========
ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (ORDER BY ts, priority) AS rn
  FROM all_events
)
SELECT
  'evt_' || rn AS event_id,
  printf('%02d:%02d.%03d',
    CAST((ts - (SELECT t_start FROM time_bounds)) / 60000000000 AS INT),
    CAST(((ts - (SELECT t_start FROM time_bounds)) / 1000000000) % 60 AS INT),
    CAST(((ts - (SELECT t_start FROM time_bounds)) / 1000000) % 1000 AS INT)
  ) AS time_offset,
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur,
  CAST(dur / 1000000 AS INT) AS dur_ms,
  event_type,
  event,
  app_package,
  CASE
    -- 启动评级
    WHEN event_type = 'cold_start' AND dur / 1e6 < 500 THEN '🟢 优秀'
    WHEN event_type = 'cold_start' AND dur / 1e6 < 1000 THEN '🟡 良好'
    WHEN event_type = 'cold_start' THEN '🔴 需优化'
    WHEN event_type = 'warm_start' AND dur / 1e6 < 300 THEN '🟢 优秀'
    WHEN event_type = 'warm_start' AND dur / 1e6 < 600 THEN '🟡 良好'
    WHEN event_type = 'warm_start' THEN '🔴 需优化'
    WHEN event_type = 'hot_start' AND dur / 1e6 < 100 THEN '🟢 优秀'
    WHEN event_type = 'hot_start' AND dur / 1e6 < 200 THEN '🟡 良好'
    WHEN event_type = 'hot_start' THEN '🔴 需优化'
    -- 点击评级
    WHEN event_type = 'tap' AND dur / 1e6 < 100 THEN '🟢'
    WHEN event_type = 'tap' AND dur / 1e6 < 200 THEN '🟡'
    WHEN event_type = 'tap' AND dur / 1e6 > 200 THEN '🔴'
    -- ANR 固定严重
    WHEN event_type = 'anr' THEN '🔴 ANR'
    -- 窗口转场评级
    WHEN event_type = 'window_transition' AND dur / 1e6 < 300 THEN '🟢'
    WHEN event_type = 'window_transition' AND dur / 1e6 < 500 THEN '🟡'
    WHEN event_type = 'window_transition' THEN '🔴'
    -- 其他事件不评级
    ELSE ''
  END AS rating
FROM ranked
ORDER BY ts, priority
LIMIT 200

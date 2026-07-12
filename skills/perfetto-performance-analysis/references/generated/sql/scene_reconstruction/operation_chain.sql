-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH time_bounds AS (
  SELECT MIN(ts) AS t_start
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
-- Screen on/off
screen_ev AS (
  SELECT ts,
    CASE screen_state WHEN 1 THEN '屏幕熄灭' WHEN 2 THEN '屏幕点亮' WHEN 3 THEN '屏幕休眠'
      ELSE '屏幕状态 ' || screen_state END AS event,
    'screen' AS category, 1 AS priority
  FROM android_screen_state WHERE dur > 0
  LIMIT 30
),
-- App launches (reclassify: bindApplication on main thread → cold)
launch_validated AS (
  SELECT s.ts, s.dur, s.package, s.startup_id,
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
  FROM android_startups s WHERE s.dur > 0
),
launch_ev AS (
  SELECT ts,
    CASE startup_type WHEN 'cold' THEN '冷启动' WHEN 'warm' THEN '温启动' WHEN 'hot' THEN '热启动'
      ELSE '启动' END || ' ' || package || ' [' || CAST(dur / 1000000 AS INT) || 'ms]' AS event,
    'app_launch' AS category, 2 AS priority
  FROM launch_validated
  LIMIT 30
),
-- Top-app switches
topapp_ev AS (
  SELECT ts,
    '切换前台: ' || str_value AS event,
    'app_switch' AS category, 3 AS priority
  FROM android_battery_stats_event_slices
  WHERE track_name = 'battery_stats.top' AND safe_dur > 100000000
  LIMIT 30
),
-- Gestures (simplified from input events)
gesture_base AS (
  SELECT
    read_time AS ts, event_action,
    SUM(CASE WHEN event_action = 'DOWN' THEN 1 ELSE 0 END) OVER (ORDER BY read_time) AS gid
  FROM android_input_events
  WHERE event_type = 'MOTION'
    AND process_name NOT IN ('system_server', '/system/bin/inputflinger')
    AND process_name NOT GLOB 'com.android.systemui*'
),
gesture_agg AS (
  SELECT gid, MIN(ts) AS ts, MAX(ts) - MIN(ts) AS dur,
    COUNT(CASE WHEN event_action = 'MOVE' THEN 1 END) AS mc
  FROM gesture_base WHERE gid > 0 GROUP BY gid HAVING COUNT(*) >= 2
),
gesture_ev AS (
  SELECT ts,
    CASE
      WHEN mc >= 3 THEN '滑动列表 (' || mc || '次移动, ' || CAST(dur / 1000000 AS INT) || 'ms)'
      WHEN dur > 500000000 AND mc <= 2 THEN '长按 (' || CAST(dur / 1000000 AS INT) || 'ms)'
      ELSE '点击'
    END AS event,
    'gesture' AS category, 4 AS priority
  FROM gesture_agg
  LIMIT 60
),
-- Foreground transitions (oom_adj crossing 0)
fg_transitions AS (
  SELECT c.ts,
    CASE
      WHEN CAST(c.value AS INT) <= 0 THEN '进入前台: ' || p.name
      ELSE '离开前台: ' || p.name
    END AS event,
    'app_state' AS category, 5 AS priority
  FROM counter c
  JOIN process_counter_track pct ON c.track_id = pct.id
  JOIN process p ON pct.upid = p.upid
  WHERE pct.name = 'oom_score_adj'
    AND p.name GLOB '*.*'
    AND p.name NOT LIKE '%system_server%'
    AND p.name NOT LIKE '%zygote%'
    AND (
      (CAST(c.value AS INT) <= 0
        AND COALESCE(
          (SELECT CAST(c2.value AS INT) FROM counter c2
           WHERE c2.track_id = c.track_id AND c2.ts < c.ts
           ORDER BY c2.ts DESC LIMIT 1), 999) > 0)
      OR
      (CAST(c.value AS INT) > 0
        AND COALESCE(
          (SELECT CAST(c2.value AS INT) FROM counter c2
           WHERE c2.track_id = c.track_id AND c2.ts < c.ts
           ORDER BY c2.ts DESC LIMIT 1), 999) <= 0)
    )
  LIMIT 30
),
-- System events (quality-gated: per-event duration thresholds)
sys_ev AS (
  SELECT ts,
    CASE
      WHEN LOWER(name) LIKE '%keyguard%dismiss%' OR LOWER(name) LIKE '%keyguard%unlock%'
        OR LOWER(name) LIKE '%lockscreen%unlock%' OR LOWER(name) LIKE '%unlock%screen%'
        THEN '解锁屏幕'
      WHEN LOWER(name) LIKE '%notificationpanel%expand%' THEN '下拉通知栏'
      WHEN LOWER(name) LIKE '%notificationpanel%collapse%' THEN '收起通知栏'
      WHEN LOWER(name) LIKE '%splitscreen%' THEN '分屏操作'
      WHEN LOWER(name) LIKE '%enterpictureinpicture%' THEN '进入画中画'
      WHEN LOWER(name) LIKE '%exitpictureinpicture%' THEN '退出画中画'
      ELSE NULL
    END AS event,
    'system' AS category, 2 AS priority
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
all_chain AS (
  SELECT * FROM screen_ev
  UNION ALL SELECT * FROM launch_ev
  UNION ALL SELECT * FROM topapp_ev
  UNION ALL SELECT * FROM gesture_ev
  UNION ALL SELECT * FROM fg_transitions
  UNION ALL SELECT * FROM sys_ev WHERE event IS NOT NULL
)
SELECT
  printf('%02d:%02d.%03d',
    CAST((ts - (SELECT t_start FROM time_bounds)) / 60000000000 AS INT),
    CAST(((ts - (SELECT t_start FROM time_bounds)) / 1000000000) % 60 AS INT),
    CAST(((ts - (SELECT t_start FROM time_bounds)) / 1000000) % 1000 AS INT)
  ) AS time_offset,
  printf('%d', ts) AS ts,
  event,
  category,
  priority
FROM all_chain
ORDER BY ts, priority
LIMIT 200

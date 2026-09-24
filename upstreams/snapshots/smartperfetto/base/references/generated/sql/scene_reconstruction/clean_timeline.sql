-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- The single read path for stdlib android_input_events. Skill contract:
-- event_action is the uppercase action without the Android prefix (MOVE, DOWN,
-- UP, CANCEL, ...). Newer trace processors report legacy atrace actions as
-- ACTION_MOVE/ACTION_DOWN/ACTION_UP; older ones reported MOVE/DOWN/UP. Every
-- other column passes through unchanged, NULL actions stay NULL. The column
-- list is the set every supported runtime has (v58.2 lacks frame_event_time);
-- keep it aligned with scrolling_analysis's input_data_fallback_view. NOT MATERIALIZED: consumers read it more than once
-- under their own filters, so SQLite should inline it rather than copy the table.
android_input_events_normalized AS NOT MATERIALIZED (
  SELECT
    dispatch_latency_dur, handling_latency_dur, ack_latency_dur,
    total_latency_dur, end_to_end_latency_dur,
    tid, thread_name, upid, pid, process_name,
    event_type,
    CASE WHEN event_action GLOB 'ACTION_*' THEN SUBSTR(event_action, 8)
      ELSE event_action END AS event_action,
    event_seq, event_channel, normalized_event_channel, input_event_id,
    read_time, dispatch_track_id, dispatch_ts, dispatch_dur,
    receive_ts, receive_dur, receive_track_id,
    frame_id, is_speculative_frame, event_time
  FROM android_input_events
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Shared input observation contract. Legacy android_input_events contains only
-- acknowledged deliveries: absence never proves that a user/device was idle.
-- Do not infer scrolling, long-click recognition or fling from MOVE counts,
-- contact duration or subsequent frames. Preserve native device/display IDs.
-- Requires fragments/android_input_events_normalized.sql listed before this
-- fragment: the legacy branch reads its prefix-free actions (MOVE, DOWN, UP).
scene_raw_input AS (
  SELECT 'android_motion_events' AS source_table, CAST(id AS TEXT) AS source_id,
    ts, 'MOTION' AS event_type,
    CASE action & 255
      WHEN 0 THEN 'DOWN' WHEN 1 THEN 'UP' WHEN 2 THEN 'MOVE'
      WHEN 3 THEN 'CANCEL' WHEN 5 THEN 'POINTER_DOWN' WHEN 6 THEN 'POINTER_UP'
      WHEN 7 THEN 'HOVER_MOVE' WHEN 8 THEN 'SCROLL' ELSE 'UNKNOWN' END AS event_action,
    device_id, display_id, source AS input_source, NULL AS upid,
    NULL AS process_name, NULL AS event_channel,
    'device:' || COALESCE(CAST(device_id AS TEXT), 'unknown:' || id) ||
      ':display:' || COALESCE(CAST(display_id AS TEXT), 'unknown') ||
      ':source:' || COALESCE(CAST(source AS TEXT), 'unknown') AS stream_key,
    'event:' || event_id AS event_key, CAST(event_id AS TEXT) AS physical_event_id, id AS source_order
  FROM android_motion_events
  UNION ALL
  SELECT 'android_key_events', CAST(id AS TEXT), ts, 'KEY',
    CASE action WHEN 0 THEN 'KEY_DOWN' WHEN 1 THEN 'KEY_UP' ELSE 'UNKNOWN' END,
    device_id, display_id, source, NULL, NULL, NULL,
    'device:' || COALESCE(CAST(device_id AS TEXT), 'unknown:' || id) ||
      ':display:' || COALESCE(CAST(display_id AS TEXT), 'unknown') ||
      ':source:' || COALESCE(CAST(source AS TEXT), 'unknown'),
    'event:' || event_id, CAST(event_id AS TEXT), id
  FROM android_key_events
  UNION ALL
  SELECT 'android_input_events',
    COALESCE(input_event_id, event_seq, '') || ':' || COALESCE(event_channel, '') || ':' || dispatch_ts,
    COALESCE(read_time, dispatch_ts, receive_ts), event_type,
    COALESCE(NULLIF(event_action, ''), 'UNKNOWN'), NULL, NULL, NULL, upid,
    process_name, event_channel,
    -- Channel + process incarnation, not pid/name or a global DOWN counter.
    COALESCE(CAST(upid AS TEXT), 'unknown') || ':' ||
      COALESCE(event_channel, 'unknown:' || COALESCE(input_event_id, event_seq, CAST(dispatch_ts AS TEXT))),
    COALESCE(input_event_id, event_seq, '') || ':' || COALESCE(event_channel, '') || ':' || dispatch_ts,
    input_event_id, dispatch_ts
  FROM android_input_events_normalized AS legacy
  WHERE NOT EXISTS (
    SELECT 1 FROM android_motion_events AS m
    WHERE legacy.input_event_id IN (CAST(m.event_id AS TEXT), printf('0x%x', m.event_id))
  ) AND NOT EXISTS (
    SELECT 1 FROM android_key_events AS k
    WHERE legacy.input_event_id IN (CAST(k.event_id AS TEXT), printf('0x%x', k.event_id))
  )
),
scene_input_facts AS (
  SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (
      PARTITION BY source_table, stream_key, event_key, ts, event_action ORDER BY source_id
    ) AS duplicate_rank FROM scene_raw_input
    WHERE ts IS NOT NULL AND ts >= (SELECT start_ts FROM trace_bounds)
      AND ts <= (SELECT end_ts FROM trace_bounds)
  ) WHERE duplicate_rank = 1
),
-- Multiple dispatch targets are observations of one physical event. Rank by
-- action availability on the receiving stream, not app/vendor name. Ambiguous
-- action-bearing recipients remain unassigned; the selected row is provenance,
-- never a claim that this recipient owns the user's action.
scene_stream_quality AS (
  SELECT stream_key, SUM(event_action != 'UNKNOWN') AS known_actions
  FROM scene_input_facts GROUP BY stream_key
),
scene_physical_ranked AS (
  SELECT f.*, q.known_actions,
    COALESCE(f.physical_event_id || ':' || f.ts, f.source_table || ':' || f.source_id) AS physical_event_key,
    ROW_NUMBER() OVER (
      PARTITION BY COALESCE(f.physical_event_id || ':' || f.ts, f.source_table || ':' || f.source_id)
      ORDER BY f.event_action = 'UNKNOWN', q.known_actions DESC, f.stream_key, f.source_id
    ) AS physical_rank
  FROM scene_input_facts f JOIN scene_stream_quality q USING (stream_key)
),
scene_physical_quality AS (
  SELECT physical_event_key, COUNT(*) AS dispatch_count,
    CASE WHEN MAX(known_actions) > 0
      THEN COUNT(DISTINCT CASE WHEN known_actions > 0 THEN stream_key END)
      ELSE COUNT(DISTINCT stream_key) END AS receiver_count,
    COUNT(DISTINCT CASE WHEN event_action != 'UNKNOWN' THEN event_action END) AS action_variants
  FROM scene_physical_ranked GROUP BY physical_event_key
),
scene_primary_input AS (
  SELECT f.source_table, f.source_id, f.ts, f.event_type,
    CASE WHEN q.action_variants > 1 THEN 'UNKNOWN' ELSE f.event_action END AS event_action,
    f.device_id, f.display_id, f.input_source,
    CASE WHEN q.receiver_count <= 1 THEN f.upid END AS upid,
    CASE WHEN q.receiver_count <= 1 THEN f.process_name END AS process_name,
    CASE WHEN q.receiver_count <= 1 THEN f.event_channel END AS event_channel,
    f.stream_key, f.source_order, f.physical_event_id, f.physical_event_key, q.dispatch_count, q.receiver_count,
    CASE WHEN q.receiver_count > 1 THEN 'multiple_recipients'
      WHEN f.upid IS NULL THEN 'unresolved' ELSE 'observed_recipient' END AS identity_status
  FROM scene_physical_ranked f JOIN scene_physical_quality q USING (physical_event_key)
  WHERE f.physical_rank = 1
),
scene_input_ordered AS (
  SELECT *, LAG(event_action) OVER (
    PARTITION BY stream_key ORDER BY ts, source_order, source_id
  ) AS previous_action
  FROM scene_primary_input
),
scene_input_grouped AS (
  SELECT *, SUM(CASE WHEN event_action = 'DOWN' OR previous_action IS NULL
      OR previous_action IN ('UP', 'CANCEL') OR event_type != 'MOTION'
      OR event_action IN ('SCROLL', 'HOVER_MOVE') THEN 1 ELSE 0 END)
    OVER (PARTITION BY stream_key ORDER BY ts, source_order, source_id ROWS UNBOUNDED PRECEDING) AS gesture_id
  FROM scene_input_ordered
),
scene_input_segmented AS (
  SELECT *, FIRST_VALUE(source_id) OVER (
      PARTITION BY stream_key, gesture_id ORDER BY ts, source_order, source_id
    ) AS start_source_id,
    FIRST_VALUE(source_id) OVER (
      PARTITION BY stream_key, gesture_id ORDER BY ts DESC, source_order DESC, source_id DESC
    ) AS end_source_id,
    FIRST_VALUE(physical_event_id) OVER (
      PARTITION BY stream_key, gesture_id ORDER BY ts, source_order, source_id
    ) AS first_physical_event_id,
    FIRST_VALUE(physical_event_id) OVER (
      PARTITION BY stream_key, gesture_id ORDER BY ts DESC, source_order DESC, source_id DESC
    ) AS last_physical_event_id
  FROM scene_input_grouped
),
scene_contacts AS (
  SELECT stream_key, gesture_id, MIN(ts) AS ts, MAX(ts) AS end_ts,
    MAX(ts) - MIN(ts) AS dur, CASE WHEN MAX(identity_status = 'multiple_recipients') = 0 THEN MAX(upid) END AS upid,
    CASE WHEN MAX(identity_status = 'multiple_recipients') = 0 THEN MAX(process_name) END AS app_package,
    CASE WHEN MAX(identity_status = 'multiple_recipients') = 0 THEN MAX(event_channel) END AS event_channel,
    MAX(device_id) AS device_id, MAX(display_id) AS display_id, MAX(input_source) AS input_source,
    SUM(dispatch_count) AS dispatch_count, MAX(receiver_count) AS receiver_count,
    CASE WHEN MAX(identity_status = 'multiple_recipients') THEN 'multiple_recipients'
      WHEN MAX(identity_status = 'unresolved') THEN 'unresolved' ELSE 'observed_recipient' END AS identity_status,
    MIN(source_table) AS source_table, MIN(start_source_id) AS source_id,
    MIN(start_source_id) || ',' || MAX(end_source_id) AS source_ids,
    MAX(first_physical_event_id) AS first_physical_event_id,
    MAX(last_physical_event_id) AS last_physical_event_id, COUNT(*) AS event_count,
    SUM(event_action = 'MOVE') AS move_count,
    SUM(event_action = 'UNKNOWN') AS missing_action_count,
    MIN(CASE WHEN event_action = 'DOWN' THEN ts END) AS down_ts,
    MAX(CASE WHEN event_action = 'UP' THEN ts END) AS up_ts,
    MAX(event_action = 'CANCEL') AS was_cancelled,
    MAX(event_type = 'KEY') AS is_key,
    -- ACTION_SCROLL describes axis input, not the physical device or app content motion.
    MAX(event_action = 'SCROLL') AS has_scroll_action,
    MAX(event_action IN ('POINTER_DOWN', 'POINTER_UP')) AS multi_pointer
  FROM scene_input_segmented GROUP BY stream_key, gesture_id
),
scene_gestures AS (
  SELECT *,
    CASE WHEN was_cancelled THEN 'cancelled'
      WHEN is_key THEN 'key' WHEN has_scroll_action THEN 'scroll_input'
      WHEN move_count > 0 THEN 'touch_move'
      WHEN missing_action_count > 0 OR down_ts IS NULL OR up_ts IS NULL THEN 'input_unknown'
      WHEN multi_pointer THEN 'input_unknown'
      WHEN dur >= 500000000 THEN 'touch_hold' ELSE 'tap' END AS gesture_type,
    CASE WHEN down_ts IS NOT NULL AND up_ts IS NOT NULL AND missing_action_count = 0
      AND was_cancelled = 0 THEN 1 ELSE 0 END AS boundary_complete,
    CASE WHEN missing_action_count > 0 OR identity_status = 'multiple_recipients' OR (is_key = 0 AND has_scroll_action = 0
      AND (down_ts IS NULL OR (up_ts IS NULL AND was_cancelled = 0)))
      THEN 'partial' ELSE 'observed' END AS source_status
  FROM scene_contacts
),
-- A one-nanosecond occupancy is used only for gap subtraction at an instant.
-- The event itself keeps dur=0. Open contacts stop at their last observation.
scene_input_occupied AS (
  SELECT ts, MIN(MAX(end_ts, ts + 1), (SELECT end_ts FROM trace_bounds)) AS end_ts
  FROM scene_gestures
),
scene_input_union_scan AS (
  SELECT *, MAX(end_ts) OVER (
    ORDER BY ts, end_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
  ) AS previous_end FROM scene_input_occupied
),
scene_input_gaps AS (
  SELECT (SELECT start_ts FROM trace_bounds) AS ts,
    COALESCE(MIN(ts), (SELECT end_ts FROM trace_bounds)) AS end_ts FROM scene_input_occupied
  UNION ALL
  SELECT previous_end, ts FROM scene_input_union_scan WHERE ts > previous_end
  UNION ALL
  SELECT MAX(end_ts), (SELECT end_ts FROM trace_bounds) FROM scene_input_occupied
  HAVING MAX(end_ts) < (SELECT end_ts FROM trace_bounds)
)
SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
WITH time_bounds AS (
  SELECT start_ts AS t_start FROM trace_bounds
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

),
-- ========== 数据源 3: 用户手势 (tap/scroll/long_press) ==========
gesture_ev AS (
  SELECT ts, dur, CASE gesture_type WHEN 'touch_move' THEN '连续触摸移动' WHEN 'touch_hold' THEN '持续触摸（长按识别未确认）' WHEN 'tap' THEN '点击接触' WHEN 'cancelled' THEN '触摸取消' WHEN 'key' THEN '按键输入' WHEN 'scroll_input' THEN '滚动轴输入（ACTION_SCROLL）' WHEN 'wheel' THEN '滚轮输入' ELSE '输入活动（动作信息不完整）' END AS event, gesture_type AS event_type,
    app_package, 'gesture' AS category, 3 AS priority FROM scene_gestures
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

),
-- ========== 数据源 6: 未观测到输入（采集完整性未确认） ==========
idle_ev AS (
  SELECT ts, end_ts - ts AS dur, '未观测到输入（采集完整性未确认）' AS event,
    'unknown' AS event_type, NULL AS app_package, 'unknown' AS category, 5 AS priority
  FROM scene_input_gaps WHERE end_ts > ts
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
  SELECT CAST(ts AS INTEGER) AS ts, CAST(dur AS INTEGER) AS dur,
    event, event_type, app_package, category, priority,
    ROW_NUMBER() OVER (ORDER BY CAST(ts AS INTEGER), priority) AS rn
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
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)

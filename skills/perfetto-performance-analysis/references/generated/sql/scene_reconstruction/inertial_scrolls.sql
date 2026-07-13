-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH RECURSIVE input_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='android_input_events'
  )
),
frame_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='actual_frame_timeline_slice'
  )
),
frame_apps AS (
  SELECT
    a.ts,
    a.dur,
    a.ts + a.dur AS end_ts,
    a.jank_type,
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
motion_base AS (
  SELECT
    read_time AS ts,
    event_action,
    process_name,
    SUM(CASE WHEN event_action = 'DOWN' THEN 1 ELSE 0 END)
      OVER (ORDER BY read_time) AS gesture_id
  FROM android_input_events
  WHERE event_type = 'MOTION'
),
gesture_stats AS (
  SELECT
    gesture_id,
    MIN(ts) AS down_ts,
    MAX(CASE WHEN event_action = 'UP' THEN ts END) AS up_ts,
    COUNT(*) AS event_count,
    SUM(CASE WHEN event_action = 'MOVE' THEN 1 ELSE 0 END) AS move_count,
    MAX(process_name) AS raw_process_name
  FROM motion_base
  WHERE gesture_id > 0
  GROUP BY gesture_id
  HAVING COUNT(*) >= 4 AND SUM(CASE WHEN event_action = 'MOVE' THEN 1 ELSE 0 END) >= 3
),
fling_windows AS (
  SELECT
    g.gesture_id,
    g.down_ts,
    g.up_ts AS inertial_start,
    MIN(
      COALESCE(LEAD(g.down_ts) OVER (ORDER BY g.down_ts), g.up_ts + 3000000000),
      g.up_ts + 3000000000
    ) AS inertial_window_end,
    g.raw_process_name
  FROM gesture_stats g
  WHERE g.up_ts IS NOT NULL
),
resolved_windows AS (
  SELECT
    w.*,
    CASE
      WHEN w.raw_process_name GLOB 'com.*'
        OR w.raw_process_name GLOB 'org.*'
        OR w.raw_process_name GLOB 'io.*'
        OR w.raw_process_name GLOB 'net.*'
      THEN w.raw_process_name
      ELSE COALESCE(
        (SELECT f.app_package
         FROM frame_apps f
         WHERE f.app_package IS NOT NULL
           AND f.app_package != ''
           AND f.app_package NOT GLOB 'surfaceflinger*'
           AND f.app_package NOT GLOB 'system_server*'
           AND f.app_package NOT GLOB 'com.android.systemui*'
           AND f.ts >= w.down_ts - 300000000
           AND f.end_ts <= w.inertial_window_end + 800000000
         GROUP BY f.app_package
         ORDER BY COUNT(*) DESC
         LIMIT 1),
        w.raw_process_name
      )
    END AS app_package
  FROM fling_windows w
),
inertial_frames AS (
  SELECT
    w.gesture_id,
    w.inertial_start,
    w.inertial_window_end,
    w.app_package,
    MAX(CASE
      WHEN f.ts IS NOT NULL
        AND (w.app_package IS NULL OR w.app_package = '' OR f.app_package = w.app_package)
      THEN f.end_ts
      ELSE NULL
    END) AS matched_inertial_end,
    MAX(f.end_ts) AS fallback_inertial_end,
    SUM(CASE
      WHEN f.ts IS NOT NULL
        AND (w.app_package IS NULL OR w.app_package = '' OR f.app_package = w.app_package)
      THEN 1 ELSE 0 END
    ) AS matched_frame_count,
    COUNT(f.ts) AS fallback_frame_count,
    SUM(CASE
      WHEN f.ts IS NOT NULL
        AND (w.app_package IS NULL OR w.app_package = '' OR f.app_package = w.app_package)
        AND f.jank_type IS NOT NULL
        AND f.jank_type != 'None'
        AND f.jank_type != ''
      THEN 1 ELSE 0 END
    ) AS matched_jank_frames,
    SUM(CASE
      WHEN f.jank_type IS NOT NULL
        AND f.jank_type != 'None'
        AND f.jank_type != ''
      THEN 1 ELSE 0 END
    ) AS fallback_jank_frames
  FROM resolved_windows w
  LEFT JOIN frame_apps f
    ON f.ts >= w.inertial_start
   AND f.ts < w.inertial_window_end
  WHERE w.inertial_window_end > w.inertial_start + 80000000
  GROUP BY w.gesture_id, w.inertial_start, w.inertial_window_end, w.app_package
),
resolved_inertial AS (
  SELECT
    gesture_id,
    inertial_start,
    MIN(
      COALESCE(
        CASE
          WHEN matched_frame_count >= 4 THEN matched_inertial_end
          ELSE fallback_inertial_end
        END,
        inertial_window_end
      ),
      inertial_window_end
    ) AS inertial_end,
    app_package,
    CASE
      WHEN matched_frame_count >= 4 THEN matched_frame_count
      ELSE fallback_frame_count
    END AS frame_count,
    CASE
      WHEN matched_frame_count >= 4 THEN matched_jank_frames
      ELSE fallback_jank_frames
    END AS jank_frames
  FROM inertial_frames
)
SELECT
  printf('%d', inertial_start) AS ts,
  printf('%d', inertial_end - inertial_start) AS dur,
  '惯性滑动' ||
  CASE
    WHEN app_package IS NOT NULL AND app_package != ''
    THEN ' [' || REPLACE(REPLACE(app_package, 'com.', ''), 'android.', '') || ']'
    ELSE ''
  END ||
  ' (' || CAST((inertial_end - inertial_start) / 1000000 AS INT) || 'ms, ' || frame_count || '帧)' AS event,
  frame_count,
  jank_frames,
  app_package,
  'inertial_scroll' AS category
FROM resolved_inertial
WHERE frame_count >= 4
  AND inertial_end > inertial_start + 80000000
ORDER BY inertial_start
LIMIT 100

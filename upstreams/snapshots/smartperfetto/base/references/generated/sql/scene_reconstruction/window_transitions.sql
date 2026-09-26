-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
SELECT
  printf('%d', s.ts) AS ts,
  printf('%d', s.dur) AS dur,
  CASE
    WHEN s.name GLOB '*openAnimation*' OR s.name GLOB '*AppTransitionReady*'
      THEN '窗口打开 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
    WHEN s.name GLOB '*closeAnimation*'
      THEN '窗口关闭 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
    WHEN s.name GLOB '*Shell transition*'
      THEN 'Shell转场 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
    WHEN s.name GLOB '*startingWindow*'
      THEN '启动窗口 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
    ELSE '窗口转场 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
  END AS event,
  CASE
    WHEN s.name GLOB '*openAnimation*' OR s.name GLOB '*AppTransitionReady*' THEN 'open'
    WHEN s.name GLOB '*closeAnimation*' THEN 'close'
    WHEN s.name GLOB '*Shell transition*' THEN 'shell'
    WHEN s.name GLOB '*startingWindow*' THEN 'starting_window'
    ELSE 'other'
  END AS transition_type,
  'window_transition' AS category
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name = 'system_server' OR p.name GLOB 'com.android.wm.shell*')
  AND s.dur > 50000000
  AND (
    s.name GLOB '*AppTransition*'
    OR s.name GLOB '*openAnimation*'
    OR s.name GLOB '*closeAnimation*'
    OR s.name GLOB '*Shell transition*'
    OR s.name GLOB '*startingWindow*'
  )
ORDER BY s.ts
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)

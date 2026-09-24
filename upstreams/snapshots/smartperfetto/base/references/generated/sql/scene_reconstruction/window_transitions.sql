-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 8832b9e9b6f0bb86a0676bcd50f367546a3406ef8111be90fe60511d26678d5b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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

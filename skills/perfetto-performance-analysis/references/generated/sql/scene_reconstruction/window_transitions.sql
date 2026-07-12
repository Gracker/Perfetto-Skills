-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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
LIMIT 100

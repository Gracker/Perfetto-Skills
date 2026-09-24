-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
SELECT
  printf('%d', s.ts) AS ts,
  printf('%d', s.dur) AS dur,
  CASE
    WHEN s.name GLOB '*BackGesture*' OR s.name GLOB '*onBackGesture*'
      OR s.name GLOB '*BackPanel*' THEN '返回手势'
    WHEN s.name GLOB '*SwipeToHome*' OR s.name GLOB '*goToHome*'
      OR s.name GLOB '*launcher*goHome*' THEN 'Home手势'
    WHEN s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*'
      THEN '最近任务手势'
    ELSE NULL
  END AS event,
  CASE
    WHEN s.name GLOB '*BackGesture*' OR s.name GLOB '*onBackGesture*'
      OR s.name GLOB '*BackPanel*' THEN 'back_key'
    WHEN s.name GLOB '*SwipeToHome*' OR s.name GLOB '*goToHome*'
      OR s.name GLOB '*launcher*goHome*' THEN 'home_key'
    WHEN s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*'
      THEN 'recents_key'
  END AS key_name,
  'navigation_key' AS category
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name GLOB 'com.android.systemui*' OR p.name GLOB '*launcher*')
  AND s.dur > 10000000
  AND (
    s.name GLOB '*BackGesture*' OR s.name GLOB '*onBackGesture*'
    OR s.name GLOB '*BackPanel*'
    OR s.name GLOB '*SwipeToHome*' OR s.name GLOB '*goToHome*'
    OR s.name GLOB '*launcher*goHome*'
    OR s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*'
  )
ORDER BY s.ts
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)

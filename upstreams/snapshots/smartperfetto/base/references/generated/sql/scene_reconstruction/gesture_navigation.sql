-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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
LIMIT 100

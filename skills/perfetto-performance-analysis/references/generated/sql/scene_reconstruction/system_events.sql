-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur,
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
    WHEN LOWER(name) LIKE '%keyguard%dismiss%'
      OR LOWER(name) LIKE '%keyguard%unlock%'
      OR LOWER(name) LIKE '%lockscreen%unlock%'
      OR LOWER(name) LIKE '%unlock%screen%'
      THEN 'screen_unlock'
    WHEN LOWER(name) LIKE '%notificationpanel%' THEN 'notification'
    WHEN LOWER(name) LIKE '%splitscreen%' THEN 'split_screen'
    WHEN LOWER(name) LIKE '%pictureinpicture%' THEN 'pip'
    ELSE 'system'
  END AS event_type,
  'system' AS category
FROM slice
WHERE (
    -- 解锁: 真实解锁 >= 100ms
    (LOWER(name) LIKE '%keyguard%dismiss%' AND dur > 100000000)
    OR (LOWER(name) LIKE '%keyguard%unlock%' AND dur > 100000000)
    OR (LOWER(name) LIKE '%lockscreen%unlock%' AND dur > 100000000)
    OR (LOWER(name) LIKE '%unlock%screen%' AND dur > 100000000)
    -- 通知栏: 面板动画 >= 200ms
    OR (LOWER(name) LIKE '%notificationpanel%expand%' AND dur > 200000000)
    OR (LOWER(name) LIKE '%notificationpanel%collapse%' AND dur > 200000000)
    -- 分屏: 用户可感知操作 >= 500ms
    OR (LOWER(name) LIKE '%splitscreen%' AND dur > 500000000)
    -- 画中画: 过渡动画 >= 300ms
    OR (LOWER(name) LIKE '%enterpictureinpicture%' AND dur > 300000000)
    OR (LOWER(name) LIKE '%exitpictureinpicture%' AND dur > 300000000)
  )
  -- 排除干扰项
  AND LOWER(name) NOT LIKE '%unlockcanvasandpost%'
  AND LOWER(name) NOT LIKE '%unlockandpost%'
  AND LOWER(name) != 'unlock'
ORDER BY ts
LIMIT 100

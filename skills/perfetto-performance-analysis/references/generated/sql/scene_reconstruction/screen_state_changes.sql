-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH RECURSIVE screen_data AS (
  SELECT 1 AS dummy WHERE EXISTS (SELECT 1 FROM sqlite_master WHERE type='table' AND name='android_screen_state')
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur,
  CASE screen_state
    WHEN 1 THEN '屏幕熄灭'
    WHEN 2 THEN '屏幕点亮'
    WHEN 3 THEN '屏幕休眠'
    ELSE '屏幕状态 ' || screen_state
  END AS event,
  'screen' AS category
FROM android_screen_state
WHERE dur > 0
ORDER BY ts
LIMIT 100

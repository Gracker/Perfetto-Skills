-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH RECURSIVE battery_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='android_battery_stats_event_slices'
  )
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', safe_dur) AS dur,
  '切换到 ' || REPLACE(REPLACE(str_value, 'com.', ''), 'android.', '') AS event,
  str_value AS app_package,
  'app_switch' AS category
FROM android_battery_stats_event_slices
WHERE track_name = 'battery_stats.top'
  AND safe_dur > 50000000
ORDER BY ts
LIMIT 100

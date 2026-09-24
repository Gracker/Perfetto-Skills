-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 8832b9e9b6f0bb86a0676bcd50f367546a3406ef8111be90fe60511d26678d5b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
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
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)

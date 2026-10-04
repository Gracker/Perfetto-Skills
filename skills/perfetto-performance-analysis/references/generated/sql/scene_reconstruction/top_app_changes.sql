-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

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

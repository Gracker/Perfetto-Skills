-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/sf_layer_count_in_range.skill.yaml
-- Source SHA-256: 32c86a668275bbbc02ac545c67d1fef7366d86414bac478468751d7dde71027a
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
-- 时间范围内所有帧的 Layer 信息
active_layers AS (
  SELECT DISTINCT
    a.layer_name,
    CASE
      WHEN '${process_name}' != '' AND a.layer_name GLOB '*${process_name}*' THEN 'app'
      WHEN a.layer_name GLOB '*StatusBar*' OR a.layer_name GLOB '*NavigationBar*'
        OR a.layer_name GLOB '*Wallpaper*' OR a.layer_name GLOB '*InputMethod*'
        OR a.layer_name GLOB '*SystemUI*' THEN 'system'
      ELSE 'other'
    END as layer_type
  FROM actual_frame_timeline_slice a
  WHERE a.ts >= ${start_ts} AND a.ts < ${end_ts}
    AND a.layer_name IS NOT NULL
),
-- 每个 SF 合成帧的并发 Layer 数
per_sf_frame_layers AS (
  SELECT
    a.display_frame_token,
    COUNT(DISTINCT a.layer_name) as layer_count
  FROM actual_frame_timeline_slice a
  WHERE a.ts >= ${start_ts} AND a.ts < ${end_ts}
    AND a.layer_name IS NOT NULL
  GROUP BY a.display_frame_token
)
SELECT
  (SELECT COUNT(*) FROM active_layers) as total_layers,
  (SELECT COUNT(*) FROM active_layers WHERE layer_type = 'app') as app_layers,
  (SELECT COUNT(*) FROM active_layers WHERE layer_type = 'system') as system_layers,
  COALESCE((SELECT ROUND(AVG(layer_count), 1) FROM per_sf_frame_layers), 0) as avg_concurrent_layers,
  COALESCE((SELECT MAX(layer_count) FROM per_sf_frame_layers), 0) as max_concurrent_layers

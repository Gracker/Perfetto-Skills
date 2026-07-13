-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/sf_layer_count_in_range.skill.yaml
-- Source SHA-256: a780be081f44b2db1942e76af09b9f252621deb1a24087e1c028cf0f40f847ff
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  a.layer_name,
  CASE
    WHEN '${process_name}' != '' AND a.layer_name GLOB '*${process_name}*' THEN 'app'
    WHEN a.layer_name GLOB '*StatusBar*' OR a.layer_name GLOB '*NavigationBar*'
      OR a.layer_name GLOB '*Wallpaper*' OR a.layer_name GLOB '*InputMethod*'
      OR a.layer_name GLOB '*SystemUI*' THEN 'system'
    ELSE 'other'
  END as layer_type,
  COUNT(*) as frame_count,
  ROUND(AVG(a.dur) / 1e6, 2) as avg_dur_ms,
  SUM(CASE WHEN a.jank_type IS NOT NULL AND a.jank_type != 'None' THEN 1 ELSE 0 END) as jank_count
FROM actual_frame_timeline_slice a
WHERE a.ts >= ${start_ts} AND a.ts < ${end_ts}
  AND a.layer_name IS NOT NULL
GROUP BY a.layer_name
ORDER BY frame_count DESC

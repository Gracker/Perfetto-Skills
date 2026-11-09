-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: a90057ce86d59a8bc077f03215ec72166ba59b83b7bdc56297cdec0a28e38622

SELECT
  s.name AS wallpaper_event,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name GLOB '*wallpaper*'
  OR p.name GLOB '*Wallpaper*'
  OR s.name GLOB '*wallpaper*'
  OR s.name GLOB '*Wallpaper*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 15

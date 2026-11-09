-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: c52bd0ea0df3f2c51b66d81b1951baa545c62d35b7e103541c2e25cf88051e39

SELECT
  s.name AS draw_event,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_dur_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_dur_ms,
  COUNT(*) AS event_count
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND (s.name GLOB '*draw*'
       OR s.name GLOB '*finishDrawing*'
       OR s.name GLOB '*performDraw*'
       OR s.name GLOB '*hwuiDraw*')
GROUP BY s.name
ORDER BY avg_dur_ms DESC
LIMIT 15

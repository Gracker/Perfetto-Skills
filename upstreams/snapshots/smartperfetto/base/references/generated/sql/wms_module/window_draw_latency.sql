-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: 4bd2c147a32250b3c3ae71af00fb8bbfb8b99256c68cc8fa44a0131ebe25d794

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: e66c60cde78f1ab8ef436f3656397aa27cad975f9c7708d388926ad8eba3010a
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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

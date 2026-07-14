-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: ec088f394851b6fb0426109a0105b0d0ae930adf759b15011ab45a18a1a5831f
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  s.name AS draw_event,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_dur_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_dur_ms,
  COUNT(*) AS event_count
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*draw*'
       OR s.name GLOB '*finishDrawing*'
       OR s.name GLOB '*performDraw*'
       OR s.name GLOB '*hwuiDraw*')
GROUP BY s.name
ORDER BY avg_dur_ms DESC
LIMIT 15

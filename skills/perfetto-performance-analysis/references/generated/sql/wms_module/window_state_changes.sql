-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: e66c60cde78f1ab8ef436f3656397aa27cad975f9c7708d388926ad8eba3010a
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  s.ts,
  s.name AS state_event,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  t.name AS thread_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name = 'system_server'
  AND (s.name GLOB '*windowFocus*'
       OR s.name GLOB '*setVisibility*'
       OR s.name GLOB '*relayoutWindow*'
       OR s.name GLOB '*finishDrawing*'
       OR s.name GLOB '*WindowState*')
  AND s.dur > 1000000
ORDER BY s.ts DESC
LIMIT 50

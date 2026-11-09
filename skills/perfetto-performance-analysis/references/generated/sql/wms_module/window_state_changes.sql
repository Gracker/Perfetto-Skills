-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: c52bd0ea0df3f2c51b66d81b1951baa545c62d35b7e103541c2e25cf88051e39

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

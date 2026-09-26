-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: e66c60cde78f1ab8ef436f3656397aa27cad975f9c7708d388926ad8eba3010a
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  s.ts,
  s.name AS transition_type,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  CASE
    WHEN s.dur / 1e6 < 200 THEN 'smooth'
    WHEN s.dur / 1e6 < 350 THEN 'acceptable'
    WHEN s.dur / 1e6 < 500 THEN 'slow'
    ELSE 'very_slow'
  END AS quality
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name = 'system_server'
  AND (s.name GLOB '*activityStart*'
       OR s.name GLOB '*activityResume*'
       OR s.name GLOB '*AppTransition*'
       OR s.name GLOB '*startActivity*')
  AND s.dur > 1000000  -- > 1ms
ORDER BY s.dur DESC
LIMIT 30

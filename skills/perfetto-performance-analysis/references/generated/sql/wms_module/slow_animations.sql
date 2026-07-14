-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: ec088f394851b6fb0426109a0105b0d0ae930adf759b15011ab45a18a1a5831f
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  s.ts,
  s.name AS animation_type,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  300 AS threshold_ms,
  CAST((s.dur / 1e6 - 300) AS INTEGER) AS exceed_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name = 'system_server' OR p.name LIKE '%systemui%')
  AND (s.name GLOB '*Animation*'
       OR s.name GLOB '*Transition*')
  AND s.dur > 300000000  -- > 300ms
ORDER BY s.dur DESC
LIMIT 20

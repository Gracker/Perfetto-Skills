-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 4a35f45abe4b7e038dbbcded10d22da6cb28b79dbd7a66e0e9d83452c778e916
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  s.ts,
  s.name AS frame_event,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  CASE
    WHEN s.dur < ${vsync_period_ns|16666667} THEN 'smooth'
    WHEN s.dur < ${vsync_period_ns|16666667} * 2 THEN 'jank'
    WHEN s.dur < ${vsync_period_ns|16666667} * 3 THEN 'severe_jank'
    ELSE 'frozen'
  END AS frame_quality,
  s.depth
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND t.tid = p.pid
  AND (s.name GLOB '*Choreographer#doFrame*'
       OR s.name GLOB '*doFrame*')
  AND s.name NOT GLOB '*resynced*'
ORDER BY s.ts
LIMIT 200

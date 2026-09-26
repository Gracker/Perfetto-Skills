-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 89db8f840e3ef0967b9ba9b94d1588c0479509358a203e9b2a8eb37910fc7509
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND t.tid = p.pid
  AND (s.name GLOB '*Choreographer#doFrame*'
       OR s.name GLOB '*doFrame*')
  AND s.name NOT GLOB '*resynced*'
ORDER BY s.ts
LIMIT 200

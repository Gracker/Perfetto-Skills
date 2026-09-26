-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 89db8f840e3ef0967b9ba9b94d1588c0479509358a203e9b2a8eb37910fc7509
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  s.ts,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  CAST((s.dur / 1e6 - ${vsync_period_ns|16666667} / 1e6) AS REAL) AS exceed_ms,
  CASE
    WHEN s.dur < ${vsync_period_ns|16666667} * 2 THEN 'jank_1_frame'
    WHEN s.dur < ${vsync_period_ns|16666667} * 3 THEN 'jank_2_frames'
    WHEN s.dur < ${vsync_period_ns|16666667} * 5 THEN 'jank_3_4_frames'
    ELSE 'jank_5plus_frames'
  END AS jank_severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND t.tid = p.pid
  AND (s.name GLOB '*Choreographer#doFrame*' OR s.name GLOB '*doFrame*')
  AND s.name NOT GLOB '*resynced*'
  AND s.dur > ${vsync_period_ns|16666667}  -- exceeds frame deadline
ORDER BY s.dur DESC
LIMIT 30

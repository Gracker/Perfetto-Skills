-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 4a35f45abe4b7e038dbbcded10d22da6cb28b79dbd7a66e0e9d83452c778e916
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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
WHERE p.name LIKE '%${package}%'
  AND t.tid = p.pid
  AND (s.name GLOB '*Choreographer#doFrame*' OR s.name GLOB '*doFrame*')
  AND s.name NOT GLOB '*resynced*'
  AND s.dur > ${vsync_period_ns|16666667}  -- exceeds frame deadline
ORDER BY s.dur DESC
LIMIT 30

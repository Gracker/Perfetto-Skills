-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 89db8f840e3ef0967b9ba9b94d1588c0479509358a203e9b2a8eb37910fc7509
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  COUNT(*) AS total_frames,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_dur_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_dur_ms,
  CAST(MIN(s.dur) / 1e6 AS REAL) AS min_dur_ms,
  SUM(CASE WHEN s.dur > ${vsync_period_ns|16666667} THEN 1 ELSE 0 END) AS jank_frames,
  SUM(CASE WHEN s.dur > ${vsync_period_ns|16666667} * 2 THEN 1 ELSE 0 END) AS severe_jank_frames,
  ROUND(SUM(CASE WHEN s.dur > ${vsync_period_ns|16666667} THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS jank_rate_pct
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND t.tid = p.pid  -- Main thread
  AND (s.name GLOB '*Choreographer#doFrame*'
       OR s.name GLOB '*doFrame*'
       OR s.name GLOB '*Choreographer*')
  AND s.name NOT GLOB '*resynced*'

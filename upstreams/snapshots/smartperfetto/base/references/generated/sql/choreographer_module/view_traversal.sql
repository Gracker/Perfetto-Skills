-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 89db8f840e3ef0967b9ba9b94d1588c0479509358a203e9b2a8eb37910fc7509
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  CASE
    WHEN s.name GLOB '*measure*' OR s.name GLOB '*Measure*' THEN 'measure'
    WHEN s.name GLOB '*layout*' OR s.name GLOB '*Layout*' THEN 'layout'
    WHEN s.name GLOB '*draw*' OR s.name GLOB '*Draw*' THEN 'draw'
    ELSE 'other'
  END AS traversal_phase,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND t.tid = p.pid
  AND (s.name GLOB '*measure*'
       OR s.name GLOB '*Measure*'
       OR s.name GLOB '*layout*'
       OR s.name GLOB '*Layout*'
       OR s.name GLOB '*draw*'
       OR s.name GLOB '*Draw*')
  AND s.dur > 100000
GROUP BY traversal_phase
ORDER BY total_ms DESC

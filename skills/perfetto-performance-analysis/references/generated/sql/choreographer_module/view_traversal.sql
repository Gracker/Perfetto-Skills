-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 4a35f45abe4b7e038dbbcded10d22da6cb28b79dbd7a66e0e9d83452c778e916
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

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
WHERE p.name LIKE '%${package}%'
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

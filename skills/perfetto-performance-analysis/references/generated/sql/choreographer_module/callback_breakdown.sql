-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 4a35f45abe4b7e038dbbcded10d22da6cb28b79dbd7a66e0e9d83452c778e916
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  CASE
    WHEN s.name GLOB '*input*' OR s.name GLOB '*Input*' THEN 'input'
    WHEN s.name GLOB '*animation*' OR s.name GLOB '*Animation*' THEN 'animation'
    WHEN s.name GLOB '*traversal*' OR s.name GLOB '*Traversal*' OR s.name GLOB '*measure*' OR s.name GLOB '*layout*' OR s.name GLOB '*draw*' THEN 'traversal'
    ELSE 'other'
  END AS callback_type,
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
  AND s.depth > 0
  AND (s.name GLOB '*input*'
       OR s.name GLOB '*Input*'
       OR s.name GLOB '*animation*'
       OR s.name GLOB '*Animation*'
       OR s.name GLOB '*traversal*'
       OR s.name GLOB '*Traversal*'
       OR s.name GLOB '*measure*'
       OR s.name GLOB '*layout*'
       OR s.name GLOB '*draw*')
GROUP BY callback_type
ORDER BY total_ms DESC

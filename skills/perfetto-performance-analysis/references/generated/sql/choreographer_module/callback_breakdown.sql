-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 50ab26350db4695faed48050143b69a472c511af5a36fcc610e6e6b192860e66

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
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
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

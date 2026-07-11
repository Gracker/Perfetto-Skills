-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: f09b8fa67e639a8b6825f4e99517b4cf82b8fae75c585d2c96f928f28e3c7f24
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  s.ts,
  s.name AS operation,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  t.name AS thread_name,
  CASE
    WHEN t.tid = p.pid THEN 'CRITICAL'
    ELSE 'normal'
  END AS severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*read*'
       OR s.name GLOB '*write*'
       OR s.name GLOB '*sqlite*'
       OR s.name GLOB '*File*'
       OR s.name GLOB '*IO*'
       OR s.name GLOB '*flush*')
  AND s.dur > 10000000  -- > 10ms
ORDER BY s.dur DESC
LIMIT 20

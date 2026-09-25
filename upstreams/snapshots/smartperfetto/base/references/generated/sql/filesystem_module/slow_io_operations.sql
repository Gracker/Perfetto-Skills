-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: bccf60688175843149ed487af73b20b0262476eef680d9ae13a75bd1ee234846
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND (s.name GLOB '*read*'
       OR s.name GLOB '*write*'
       OR s.name GLOB '*sqlite*'
       OR s.name GLOB '*File*'
       OR s.name GLOB '*IO*'
       OR s.name GLOB '*flush*')
  AND s.dur > 10000000  -- > 10ms
ORDER BY s.dur DESC
LIMIT 20

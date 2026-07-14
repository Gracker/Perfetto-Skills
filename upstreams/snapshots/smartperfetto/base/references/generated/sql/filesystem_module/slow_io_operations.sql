-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: e2ba372b872ef978f342ad67351e9294edd801ecae1c716d110212a8bc88cd94
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: e2ba372b872ef978f342ad67351e9294edd801ecae1c716d110212a8bc88cd94
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

SELECT
  s.ts,
  s.name AS db_operation,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  t.name AS thread_name,
  CASE
    WHEN t.tid = p.pid THEN 'main_thread'
    ELSE 'background'
  END AS thread_type
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  -- Slice names are heuristic attribution only. Require a database
  -- namespace/product signal; generic "query"/"transaction" names are
  -- common outside storage and must not be promoted as DB evidence.
  AND (LOWER(s.name) GLOB '*sqlite*'
       OR LOWER(s.name) GLOB '*android.database*'
       OR LOWER(s.name) GLOB '*room*database*')
  AND s.dur > 500000  -- > 0.5ms
ORDER BY s.dur DESC
LIMIT 30

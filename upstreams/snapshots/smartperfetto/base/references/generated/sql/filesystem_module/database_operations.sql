-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: 374e420be6fc4ef20beaf8f62a49e88d1241daf9f337af2b57cc2689d9987ee8
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: e2ba372b872ef978f342ad67351e9294edd801ecae1c716d110212a8bc88cd94
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

SELECT
  s.ts,
  s.name AS io_operation,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  t.name AS thread_name,
  p.name AS process_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND t.tid = p.pid  -- Main thread: tid == pid
  AND (s.name GLOB '*read*'
       OR s.name GLOB '*Read*'
       OR s.name GLOB '*write*'
       OR s.name GLOB '*Write*'
       OR s.name GLOB '*sqlite*'
       OR s.name GLOB '*SQLite*'
       OR s.name GLOB '*SharedPreferences*'
       OR s.name GLOB '*File*'
       OR s.name GLOB '*open*'
       OR s.name GLOB '*flush*')
  AND s.dur > 1000000  -- > 1ms
ORDER BY s.dur DESC
LIMIT 30

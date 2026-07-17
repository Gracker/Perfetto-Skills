-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: e2ba372b872ef978f342ad67351e9294edd801ecae1c716d110212a8bc88cd94
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  CASE
    WHEN s.name GLOB '*read*' OR s.name GLOB '*Read*' THEN 'read'
    WHEN s.name GLOB '*write*' OR s.name GLOB '*Write*' THEN 'write'
    WHEN s.name GLOB '*sqlite*' OR s.name GLOB '*SQLite*' OR s.name GLOB '*database*' THEN 'database'
    WHEN s.name GLOB '*SharedPreferences*' OR s.name GLOB '*sharedpref*' THEN 'shared_prefs'
    WHEN s.name GLOB '*open*' OR s.name GLOB '*Open*' THEN 'open'
    WHEN s.name GLOB '*flush*' OR s.name GLOB '*sync*' THEN 'sync'
    ELSE 'other'
  END AS io_type,
  COUNT(*) AS operation_count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*read*'
       OR s.name GLOB '*Read*'
       OR s.name GLOB '*write*'
       OR s.name GLOB '*Write*'
       OR s.name GLOB '*sqlite*'
       OR s.name GLOB '*SQLite*'
       OR s.name GLOB '*database*'
       OR s.name GLOB '*SharedPreferences*'
       OR s.name GLOB '*open*'
       OR s.name GLOB '*flush*'
       OR s.name GLOB '*sync*'
       OR s.name GLOB '*File*'
       OR s.name GLOB '*IO*')
  AND s.dur > 100000  -- > 0.1ms
GROUP BY io_type
ORDER BY total_ms DESC

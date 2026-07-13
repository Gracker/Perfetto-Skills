-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: f09b8fa67e639a8b6825f4e99517b4cf82b8fae75c585d2c96f928f28e3c7f24
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

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

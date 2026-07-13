-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: f09b8fa67e639a8b6825f4e99517b4cf82b8fae75c585d2c96f928f28e3c7f24
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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
  AND (s.name GLOB '*sqlite*'
       OR s.name GLOB '*SQLite*'
       OR s.name GLOB '*database*'
       OR s.name GLOB '*query*'
       OR s.name GLOB '*Query*'
       OR s.name GLOB '*transaction*'
       OR s.name GLOB '*cursor*'
       OR s.name GLOB '*Room*')
  AND s.dur > 500000  -- > 0.5ms
ORDER BY s.dur DESC
LIMIT 30

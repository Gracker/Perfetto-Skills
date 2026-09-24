-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: 374e420be6fc4ef20beaf8f62a49e88d1241daf9f337af2b57cc2689d9987ee8
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT
  s.ts,
  s.name AS sp_operation,
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
  -- apply/commit are generic method names; only accept an explicit
  -- SharedPreferences namespace in the trace slice.
  AND (LOWER(s.name) GLOB '*sharedpreferences*'
       OR LOWER(s.name) GLOB '*sharedpref*'
       OR LOWER(s.name) GLOB '*shared preferences*')
  AND s.dur > 500000
ORDER BY s.dur DESC
LIMIT 20

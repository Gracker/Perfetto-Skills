-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: e628d2472eff6e2c0726180c21aa7a192edad2766c416d45595d4e5060b31719

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
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  -- apply/commit are generic method names; only accept an explicit
  -- SharedPreferences namespace in the trace slice.
  AND (LOWER(s.name) GLOB '*sharedpreferences*'
       OR LOWER(s.name) GLOB '*sharedpref*'
       OR LOWER(s.name) GLOB '*shared preferences*')
  AND s.dur > 500000
ORDER BY s.dur DESC
LIMIT 20

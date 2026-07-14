-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: e2ba372b872ef978f342ad67351e9294edd801ecae1c716d110212a8bc88cd94
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: 09423f22ca1cc723d498d6e9ecfbfb935d5cf177154c5eab813f3bf7d0bcef40
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  s.ts,
  s.name AS launch_event,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  t.name AS thread_name,
  p.name AS process_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name LIKE '%launcher%'
       OR p.name LIKE '%Launcher%'
       OR p.name LIKE '%trebuchet%'
       OR p.name LIKE '%nexuslauncher%')
  AND (s.name GLOB '*startActivity*'
       OR s.name GLOB '*launchApp*'
       OR s.name GLOB '*onClick*'
       OR s.name GLOB '*ItemClick*'
       OR s.name GLOB '*touch*')
  AND s.dur > 100000  -- > 0.1ms
ORDER BY s.ts
LIMIT 30

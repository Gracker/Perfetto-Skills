-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: a90057ce86d59a8bc077f03215ec72166ba59b83b7bdc56297cdec0a28e38622

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

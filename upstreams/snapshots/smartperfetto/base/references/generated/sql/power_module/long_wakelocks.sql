-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: cd2beb4f76696242a572e25220b5f4bfb755d932498796fb7b3098dd5759ec18

SELECT
  s.ts,
  s.name AS wakelock_name,
  CAST(s.dur / 1e6 AS INTEGER) AS dur_ms,
  t.name AS thread_name,
  p.name AS process_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (s.name GLOB '*wakelock*'
       OR s.name GLOB '*Wakelock*'
       OR s.name GLOB '*WAKE_LOCK*')
  AND s.dur > 1000000000  -- > 1 second
ORDER BY s.dur DESC
LIMIT 20

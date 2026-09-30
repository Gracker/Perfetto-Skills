-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: b1684cac1874ae453391ccfe88614289405b052dad8ab7ec594255347bb37acb

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

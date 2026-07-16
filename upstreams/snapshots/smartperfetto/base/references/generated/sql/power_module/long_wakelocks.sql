-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 693f6663e128d50376bf9b5d140720a74789e0354b6c784ed0a7b1d8ddd85bd5
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  s.ts,
  s.name AS lock_event,
  CAST(s.dur / 1e6 AS REAL) AS wait_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND t.tid = p.pid  -- Main thread
  AND (s.name GLOB '*lock*'
       OR s.name GLOB '*Lock*'
       OR s.name GLOB '*mutex*'
       OR s.name GLOB '*monitor*'
       OR s.name GLOB '*contention*'
       OR s.name GLOB '*wait*')
  AND s.dur > 1000000
ORDER BY s.dur DESC
LIMIT 20

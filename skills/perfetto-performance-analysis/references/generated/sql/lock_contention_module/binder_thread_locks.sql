-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 693f6663e128d50376bf9b5d140720a74789e0354b6c784ed0a7b1d8ddd85bd5
-- Source commit: 12f4004d5cdc2aeac76d3afce68ef2e3e87d500f

SELECT
  t.name AS binder_thread,
  s.name AS lock_event,
  CAST(s.dur / 1e6 AS REAL) AS wait_ms,
  s.ts
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND t.name LIKE '%Binder%'
  AND (s.name GLOB '*lock*'
       OR s.name GLOB '*Lock*'
       OR s.name GLOB '*mutex*'
       OR s.name GLOB '*contention*')
  AND s.dur > 1000000
ORDER BY s.dur DESC
LIMIT 15

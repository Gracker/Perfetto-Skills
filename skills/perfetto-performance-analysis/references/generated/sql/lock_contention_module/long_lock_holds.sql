-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 693f6663e128d50376bf9b5d140720a74789e0354b6c784ed0a7b1d8ddd85bd5
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  s.ts,
  s.name AS lock_operation,
  CAST(s.dur / 1e6 AS REAL) AS hold_ms,
  t.name AS holder_thread,
  t.tid AS holder_tid
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND (s.name GLOB '*holding*lock*'
       OR s.name GLOB '*acquired*'
       OR s.name GLOB '*lock*held*'
       OR (s.name GLOB '*synchronized*' AND s.dur > 5000000))
  AND s.dur > 5000000  -- > 5ms
ORDER BY s.dur DESC
LIMIT 15

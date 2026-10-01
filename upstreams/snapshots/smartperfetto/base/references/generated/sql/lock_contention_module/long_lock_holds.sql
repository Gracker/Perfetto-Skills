-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 106819ab92ac89738c756cd296dd1da8aac142910477fdb313a8dc616a50bd08

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

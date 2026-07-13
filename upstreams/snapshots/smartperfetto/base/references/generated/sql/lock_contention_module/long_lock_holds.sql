-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*holding*lock*'
       OR s.name GLOB '*acquired*'
       OR s.name GLOB '*lock*held*'
       OR (s.name GLOB '*synchronized*' AND s.dur > 5000000))
  AND s.dur > 5000000  -- > 5ms
ORDER BY s.dur DESC
LIMIT 15

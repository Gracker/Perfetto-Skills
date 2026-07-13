-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  s.ts,
  s.name AS lock_event,
  CAST(s.dur / 1e6 AS REAL) AS wait_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
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

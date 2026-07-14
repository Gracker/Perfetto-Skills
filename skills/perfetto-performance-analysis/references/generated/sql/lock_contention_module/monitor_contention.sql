-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  s.ts,
  s.name AS monitor_event,
  CAST(s.dur / 1e6 AS REAL) AS wait_ms,
  t.name AS waiting_thread,
  t.tid AS waiting_tid
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*monitor*'
       OR s.name GLOB '*Monitor*'
       OR s.name GLOB '*LockContention*'
       OR s.name GLOB '*synchronized*')
  AND s.dur > 1000000  -- > 1ms
ORDER BY s.dur DESC
LIMIT 30

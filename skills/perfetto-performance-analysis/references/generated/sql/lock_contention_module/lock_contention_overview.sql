-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  s.name AS lock_event,
  COUNT(*) AS event_count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_wait_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_wait_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_wait_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*lock*'
       OR s.name GLOB '*Lock*'
       OR s.name GLOB '*mutex*'
       OR s.name GLOB '*Mutex*'
       OR s.name GLOB '*monitor*'
       OR s.name GLOB '*Monitor*'
       OR s.name GLOB '*contention*'
       OR s.name GLOB '*wait*'
       OR s.name GLOB '*futex*')
  AND s.dur > 100000  -- > 0.1ms
GROUP BY s.name
ORDER BY total_wait_ms DESC
LIMIT 20

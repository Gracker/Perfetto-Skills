-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  t.name AS binder_thread,
  s.name AS lock_event,
  CAST(s.dur / 1e6 AS REAL) AS wait_ms,
  s.ts
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND t.name LIKE '%Binder%'
  AND (s.name GLOB '*lock*'
       OR s.name GLOB '*Lock*'
       OR s.name GLOB '*mutex*'
       OR s.name GLOB '*contention*')
  AND s.dur > 1000000
ORDER BY s.dur DESC
LIMIT 15

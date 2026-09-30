-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: bf6c73b0c93093c4aeb7accec76145b98122bfe7a5dd171dac407ff4f7f808d9

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

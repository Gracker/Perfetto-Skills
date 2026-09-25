-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 693f6663e128d50376bf9b5d140720a74789e0354b6c784ed0a7b1d8ddd85bd5
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: f00717aba46f44cda52a71b3aac619d9a3dabf1eea6b54e5757a38a480c000bc

SELECT
  s.name AS alloc_event,
  COUNT(*) AS event_count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND (s.name GLOB '*alloc*'
       OR s.name GLOB '*Alloc*'
       OR s.name GLOB '*malloc*'
       OR s.name GLOB '*mmap*')
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 15

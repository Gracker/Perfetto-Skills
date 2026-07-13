-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 4554575145483d31969e45a7f620e2babcd548a6287d30687a303389845885bd
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  s.name AS alloc_event,
  COUNT(*) AS event_count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*alloc*'
       OR s.name GLOB '*Alloc*'
       OR s.name GLOB '*malloc*'
       OR s.name GLOB '*mmap*')
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 15

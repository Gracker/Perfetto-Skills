-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: c4d29f5ee21c06081cc03ddeefcc79718e488db294e4623000e124ce9c292f0b

SELECT
  ct.name AS memory_type,
  CAST(MIN(c.value) / 1024 / 1024 AS INTEGER) AS min_mb,
  CAST(MAX(c.value) / 1024 / 1024 AS INTEGER) AS max_mb,
  CAST(AVG(c.value) / 1024 / 1024 AS INTEGER) AS avg_mb,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name LIKE '%mem%'
  OR ct.name LIKE '%Mem%'
  OR ct.name LIKE '%memory%'
  OR ct.name LIKE '%Memory%'
  OR ct.name LIKE '%MemFree%'
  OR ct.name LIKE '%MemAvailable%'
  OR ct.name LIKE '%Cached%'
  OR ct.name LIKE '%Buffers%'
  OR ct.name LIKE '%SwapFree%'
GROUP BY ct.name
ORDER BY avg_mb DESC
LIMIT 20

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: c4d29f5ee21c06081cc03ddeefcc79718e488db294e4623000e124ce9c292f0b

SELECT
  ct.name AS buffer_type,
  CAST(MIN(c.value) / 1024 / 1024 AS INTEGER) AS min_mb,
  CAST(MAX(c.value) / 1024 / 1024 AS INTEGER) AS max_mb,
  CAST((MAX(c.value) - MIN(c.value)) / 1024 / 1024 AS INTEGER) AS growth_mb,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE ct.name GLOB '*dmabuf*'
  OR ct.name GLOB '*ion*'
  OR ct.name GLOB '*gpu*mem*'
  OR ct.name GLOB '*graphics*'
GROUP BY ct.name
ORDER BY max_mb DESC

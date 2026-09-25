-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 414d1472ca7ef5f999ad8066cb1322622316c622e4bb29e5d0ce7f7b0e4fad9b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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

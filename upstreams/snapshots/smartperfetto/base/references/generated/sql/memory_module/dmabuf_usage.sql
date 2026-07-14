-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 4554575145483d31969e45a7f620e2babcd548a6287d30687a303389845885bd
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: ae5d2db90bbb80ca10096056d71b8feb7cde4b2284fdcbe629a2acb1abd990c1
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  slice.name AS jit_event,
  COUNT(*) AS event_count,
  CAST(SUM(slice.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(slice.dur) / 1e6 AS REAL) AS avg_ms
FROM slice
WHERE slice.name LIKE '%JIT%'
  OR slice.name LIKE '%compile%'
GROUP BY slice.name
ORDER BY total_ms DESC

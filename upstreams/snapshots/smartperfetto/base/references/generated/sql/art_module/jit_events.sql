-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: ccf7ffb32cfd7c7aec9b11b5f2ea46b43afcc7223ca47f28d55eff74b710bb95

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

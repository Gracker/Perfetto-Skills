-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: 77e992fb9b0d483e4e6c1956dd1023052e4c345a03137e372448ad8c22892918
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  'InputReader' AS stage,
  ROUND(AVG(dur) / 1e6, 2) AS avg_ms
FROM slice
WHERE name LIKE '%InputReader%'
UNION ALL
SELECT
  'InputDispatcher' AS stage,
  ROUND(AVG(dur) / 1e6, 2) AS avg_ms
FROM slice
WHERE name LIKE '%InputDispatcher%'
UNION ALL
SELECT
  'AppHandling' AS stage,
  ROUND(AVG(dur) / 1e6, 2) AS avg_ms
FROM slice
WHERE name LIKE '%deliverInputEvent%'

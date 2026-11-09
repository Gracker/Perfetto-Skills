-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: 44cab906fb8f37dddce79e2c7407f2cef7d4c52307cb65f9890df0a5aaad681d

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: 77e992fb9b0d483e4e6c1956dd1023052e4c345a03137e372448ad8c22892918
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  COUNT(*) AS total_clicks,
  ROUND(AVG(dur / 1e6), 1) AS avg_latency_ms,
  ROUND(MAX(dur / 1e6), 1) AS max_latency_ms,
  SUM(CASE WHEN dur > 100000000 THEN 1 ELSE 0 END) AS slow_clicks
FROM slice
WHERE name LIKE '%deliverInputEvent%'
  OR name LIKE '%dispatchTouchEvent%'

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: 77e992fb9b0d483e4e6c1956dd1023052e4c345a03137e372448ad8c22892918
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  COUNT(*) AS total_clicks,
  ROUND(AVG(dur / 1e6), 1) AS avg_latency_ms,
  ROUND(MAX(dur / 1e6), 1) AS max_latency_ms,
  SUM(CASE WHEN dur > 100000000 THEN 1 ELSE 0 END) AS slow_clicks
FROM slice
WHERE name LIKE '%deliverInputEvent%'
  OR name LIKE '%dispatchTouchEvent%'

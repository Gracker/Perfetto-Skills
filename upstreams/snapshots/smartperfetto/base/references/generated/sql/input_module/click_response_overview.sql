-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: e514d3ba027d776732f4f451e54e709f259d7b79e371ab403971fb4925dfa977

SELECT
  COUNT(*) AS total_clicks,
  ROUND(AVG(dur / 1e6), 1) AS avg_latency_ms,
  ROUND(MAX(dur / 1e6), 1) AS max_latency_ms,
  SUM(CASE WHEN dur > 100000000 THEN 1 ELSE 0 END) AS slow_clicks
FROM slice
WHERE name LIKE '%deliverInputEvent%'
  OR name LIKE '%dispatchTouchEvent%'

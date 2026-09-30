-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: e514d3ba027d776732f4f451e54e709f259d7b79e371ab403971fb4925dfa977

SELECT
  ts,
  ROUND(dur / 1e6, 1) AS latency_ms,
  name AS event_type,
  track_id
FROM slice
WHERE (name LIKE '%deliverInputEvent%' OR name LIKE '%dispatchTouchEvent%')
  AND dur > 50000000
ORDER BY dur DESC
LIMIT 20

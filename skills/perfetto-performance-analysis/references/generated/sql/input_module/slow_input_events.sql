-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: 44cab906fb8f37dddce79e2c7407f2cef7d4c52307cb65f9890df0a5aaad681d

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

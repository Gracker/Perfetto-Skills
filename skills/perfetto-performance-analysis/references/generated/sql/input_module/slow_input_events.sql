-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: 77e992fb9b0d483e4e6c1956dd1023052e4c345a03137e372448ad8c22892918
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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

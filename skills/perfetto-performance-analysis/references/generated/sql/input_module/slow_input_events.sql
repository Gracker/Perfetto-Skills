-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/input_module.skill.yaml
-- Source SHA-256: 77e992fb9b0d483e4e6c1956dd1023052e4c345a03137e372448ad8c22892918
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

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

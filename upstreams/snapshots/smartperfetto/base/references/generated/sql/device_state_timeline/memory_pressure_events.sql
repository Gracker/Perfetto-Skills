-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/device_state_timeline.skill.yaml
-- Source SHA-256: 4bdcfcf7ad8209f5290e1f7a6e7ff4d7886529fa423c89e440374bc4111114d1

WITH mem_samples AS (
  SELECT
    c.ts,
    ct.name as counter_name,
    c.value,
    LAG(c.value) OVER (PARTITION BY ct.name ORDER BY c.ts) as prev_value,
    ROW_NUMBER() OVER (PARTITION BY ct.name ORDER BY c.ts) as rn,
    COUNT(*) OVER (PARTITION BY ct.name) as total_samples
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*mem.*pressure*' OR ct.name GLOB '*MemFree*'
         OR ct.name GLOB '*MemAvailable*' OR ct.name GLOB '*psi*mem*'
         OR ct.name GLOB '*lowmemkiller*')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts <= ${end_ts})
)
SELECT
  printf('%d', ts) as ts,
  counter_name,
  ROUND(value, 2) as value,
  ROUND(prev_value, 2) as prev_value,
  ROUND(value - COALESCE(prev_value, value), 2) as delta
FROM mem_samples
WHERE rn % MAX(1, total_samples / 80) = 0
   OR ABS(value - COALESCE(prev_value, value)) > value * 0.1
ORDER BY ts ASC
LIMIT 300

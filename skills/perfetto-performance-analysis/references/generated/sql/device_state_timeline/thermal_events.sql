-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/device_state_timeline.skill.yaml
-- Source SHA-256: 706331c8ba61ce76147693d6cb6cdf6758bdfc7ecab0b035ab635b86002efd08
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH thermal_samples AS (
  SELECT
    c.ts,
    ct.name as sensor_name,
    CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END as temp_c,
    LAG(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END)
      OVER (PARTITION BY ct.name ORDER BY c.ts) as prev_temp_c,
    ROW_NUMBER() OVER (PARTITION BY ct.name ORDER BY c.ts) as rn,
    COUNT(*) OVER (PARTITION BY ct.name) as total_samples
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*thermal_zone*' OR ct.name GLOB '*Temperature*'
         OR ct.name GLOB '*temp*' OR ct.name GLOB '*tsens*')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts <= ${end_ts})
)
SELECT
  printf('%d', ts) as ts,
  sensor_name,
  ROUND(temp_c, 1) as temp_c,
  ROUND(temp_c - COALESCE(prev_temp_c, temp_c), 1) as delta_c,
  CASE
    WHEN temp_c > 80 THEN 'critical'
    WHEN temp_c > 60 THEN 'warning'
    WHEN temp_c > 45 THEN 'normal'
    ELSE 'cool'
  END as severity
FROM thermal_samples
-- 采样：取均匀分布样本 + 高温点 + 大跳变
WHERE rn % MAX(1, total_samples / 100) = 0
   OR temp_c > 60
   OR ABS(temp_c - COALESCE(prev_temp_c, temp_c)) > 3
ORDER BY ts ASC
LIMIT 300

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  ct.name as sensor_name,
  COUNT(*) as sample_count,
  -- 归一化：millidegrees (>1000) → Celsius
  ROUND(MIN(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END), 1) as min_temp_c,
  ROUND(MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END), 1) as max_temp_c,
  ROUND(AVG(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END), 1) as avg_temp_c,
  ROUND(
    MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END)
    - MIN(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END), 1
  ) as temp_range_c,
  CASE
    WHEN MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END) > 80 THEN '严重过热'
    WHEN MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END) > 60 THEN '温度偏高'
    WHEN MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END) > 45 THEN '温度正常'
    ELSE '温度良好'
  END as temp_severity
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE (
    ct.name LIKE '%thermal%'
    OR ct.name LIKE '%temp%'
    OR ct.name LIKE '%temperature%'
    OR ct.name LIKE '%tsens%'
  )
  AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY ct.name
ORDER BY max_temp_c DESC

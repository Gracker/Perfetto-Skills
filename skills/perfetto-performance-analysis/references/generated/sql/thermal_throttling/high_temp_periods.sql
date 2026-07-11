-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH high_temp_samples AS (
  SELECT
    c.ts,
    ct.name as sensor_name,
    CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END as temp_c
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (
      ct.name LIKE '%thermal%'
      OR ct.name LIKE '%temp%'
      OR ct.name LIKE '%tsens%'
    )
    AND (CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END) > 60
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
)
SELECT
  sensor_name,
  printf('%d', MIN(ts)) as start_ts,
  printf('%d', MAX(ts)) as end_ts,
  ROUND((MAX(ts) - MIN(ts)) / 1e9, 2) as duration_sec,
  ROUND(MAX(temp_c), 1) as peak_temp_c,
  COUNT(*) as sample_count
FROM high_temp_samples
GROUP BY sensor_name
HAVING COUNT(*) > 1
ORDER BY peak_temp_c DESC

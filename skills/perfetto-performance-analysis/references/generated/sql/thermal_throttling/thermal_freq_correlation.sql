-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH
time_range AS (
  SELECT MIN(ts) as base_ts FROM counter
),
thermal_by_sec AS (
  SELECT
    CAST((c.ts - (SELECT base_ts FROM time_range)) / 1e9 AS INT) as second,
    MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END) as max_temp_c
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name LIKE '%thermal%' OR ct.name LIKE '%temp%' OR ct.name LIKE '%tsens%')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  GROUP BY CAST((c.ts - (SELECT base_ts FROM time_range)) / 1e9 AS INT)
),
freq_by_sec AS (
  SELECT
    CAST((c.ts - (SELECT base_ts FROM time_range)) / 1e9 AS INT) as second,
    AVG(c.value / 1000.0) as avg_freq_mhz,
    MAX(c.value / 1000.0) as max_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  GROUP BY CAST((c.ts - (SELECT base_ts FROM time_range)) / 1e9 AS INT)
),
global_max_freq AS (
  SELECT MAX(c.value / 1000.0) as global_max_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
)
SELECT
  t.second,
  ROUND(t.max_temp_c, 1) as max_temp_c,
  ROUND(f.avg_freq_mhz, 0) as avg_freq_mhz,
  ROUND(f.avg_freq_mhz * 100.0 / NULLIF((SELECT global_max_mhz FROM global_max_freq), 0), 1) as freq_ratio_pct,
  CASE
    WHEN t.max_temp_c > 70 AND f.avg_freq_mhz < (SELECT global_max_mhz FROM global_max_freq) * 0.5
      THEN 'thermal_throttled'
    WHEN t.max_temp_c > 60 AND f.avg_freq_mhz < (SELECT global_max_mhz FROM global_max_freq) * 0.7
      THEN 'moderate_throttle'
    WHEN t.max_temp_c > 60 THEN 'high_temp'
    ELSE 'normal'
  END as status
FROM thermal_by_sec t
JOIN freq_by_sec f ON t.second = f.second
ORDER BY t.second
LIMIT 120

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH freq_with_max AS (
  SELECT
    cct.cpu as cpu_id,
    c.ts,
    c.value / 1000.0 as freq_mhz,
    LAG(c.value / 1000.0) OVER (PARTITION BY cct.cpu ORDER BY c.ts) as prev_freq_mhz,
    MAX(c.value / 1000.0) OVER (PARTITION BY cct.cpu) as cpu_max_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
)
SELECT
  printf('%d', ts) as ts,
  cpu_id,
  ROUND(prev_freq_mhz, 0) as prev_freq_mhz,
  ROUND(freq_mhz, 0) as new_freq_mhz,
  ROUND((prev_freq_mhz - freq_mhz) * 100.0 / prev_freq_mhz, 1) as drop_pct,
  CASE
    WHEN freq_mhz < cpu_max_freq_mhz * 0.3 THEN 'critical'
    WHEN freq_mhz < cpu_max_freq_mhz * 0.5 THEN 'warning'
    ELSE 'notice'
  END as severity
FROM freq_with_max
WHERE prev_freq_mhz IS NOT NULL
  AND freq_mhz < prev_freq_mhz * 0.7  -- 30%+ 降频
ORDER BY (prev_freq_mhz - freq_mhz) DESC
LIMIT 30

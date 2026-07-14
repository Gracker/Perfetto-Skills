-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/device_state_timeline.skill.yaml
-- Source SHA-256: 706331c8ba61ce76147693d6cb6cdf6758bdfc7ecab0b035ab635b86002efd08
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH freq_changes AS (
  SELECT
    c.ts,
    cct.cpu,
    ROUND(c.value / 1000.0, 0) as freq_mhz,
    LAG(ROUND(c.value / 1000.0, 0)) OVER (PARTITION BY cct.cpu ORDER BY c.ts) as prev_freq_mhz,
    ROW_NUMBER() OVER (PARTITION BY cct.cpu ORDER BY c.ts) as rn,
    COUNT(*) OVER (PARTITION BY cct.cpu) as total_samples
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts <= ${end_ts})
)
SELECT
  printf('%d', ts) as ts,
  cpu,
  freq_mhz,
  prev_freq_mhz,
  ROUND(freq_mhz - COALESCE(prev_freq_mhz, freq_mhz), 0) as delta_mhz,
  CASE
    WHEN prev_freq_mhz IS NULL THEN 'initial'
    WHEN freq_mhz > prev_freq_mhz THEN 'boost'
    WHEN freq_mhz < prev_freq_mhz THEN 'throttle'
    ELSE 'stable'
  END as transition_type
FROM freq_changes
WHERE prev_freq_mhz IS NULL
   OR freq_mhz != prev_freq_mhz
ORDER BY ts ASC
LIMIT 500

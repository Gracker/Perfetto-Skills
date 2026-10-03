-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/device_state_timeline.skill.yaml
-- Source SHA-256: 4bdcfcf7ad8209f5290e1f7a6e7ff4d7886529fa423c89e440374bc4111114d1

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
    -- A frequency change alone is not throttling: a governor lowers the
    -- clock for load as often as a limit does.
    WHEN freq_mhz > prev_freq_mhz THEN 'increase'
    WHEN freq_mhz < prev_freq_mhz THEN 'decrease'
    ELSE 'stable'
  END as transition_type
FROM freq_changes
WHERE prev_freq_mhz IS NULL
   OR freq_mhz != prev_freq_mhz
ORDER BY ts ASC
LIMIT 500

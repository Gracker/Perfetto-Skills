-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_timeline.skill.yaml
-- Source SHA-256: 1e522ca6fb183f6510f044547c8d5f97b82b8de7b181ceeae96795b0b1e8fe84
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
freq_events AS (
  SELECT
    c.ts,
    t.cpu,
    c.value as freq_khz,
    COALESCE(ct.core_type, 'unknown') as core_type,
    LAG(c.value) OVER (PARTITION BY t.cpu ORDER BY c.ts) as prev_freq_khz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  LEFT JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
  WHERE t.name = 'cpufreq'
    AND c.ts >= ${start_ts}
    AND c.ts < ${end_ts}
)
SELECT
  printf('%d', ts) as ts,
  ROUND((ts - ${start_ts}) / 1e6, 2) as relative_ms,
  cpu,
  core_type,
  ROUND(freq_khz / 1000, 0) as freq_mhz,
  ROUND(COALESCE(prev_freq_khz, freq_khz) / 1000, 0) as prev_freq_mhz,
  CASE
    WHEN freq_khz > COALESCE(prev_freq_khz, freq_khz) THEN 'up'
    WHEN freq_khz < COALESCE(prev_freq_khz, freq_khz) THEN 'down'
    ELSE 'stable'
  END as change_direction
FROM freq_events
WHERE freq_khz != COALESCE(prev_freq_khz, 0)
ORDER BY ts, cpu

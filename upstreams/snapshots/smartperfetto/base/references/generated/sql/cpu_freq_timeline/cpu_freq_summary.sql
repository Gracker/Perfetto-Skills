-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_timeline.skill.yaml
-- Source SHA-256: 1e522ca6fb183f6510f044547c8d5f97b82b8de7b181ceeae96795b0b1e8fe84
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
freq_data AS (
  SELECT
    t.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    c.value as freq_khz,
    LAG(c.value) OVER (PARTITION BY t.cpu ORDER BY c.ts) as prev_freq_khz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  LEFT JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
  WHERE t.name = 'cpufreq'
    AND c.ts >= ${start_ts}
    AND c.ts < ${end_ts}
)
SELECT
  core_type,
  COUNT(DISTINCT cpu) as cpu_count,
  ROUND(AVG(freq_khz) / 1000, 0) as avg_freq_mhz,
  ROUND(MAX(freq_khz) / 1000, 0) as max_freq_mhz,
  ROUND(MIN(freq_khz) / 1000, 0) as min_freq_mhz,
  SUM(CASE WHEN freq_khz != COALESCE(prev_freq_khz, freq_khz) THEN 1 ELSE 0 END) as freq_changes,
  SUM(CASE WHEN freq_khz < COALESCE(prev_freq_khz, freq_khz) THEN 1 ELSE 0 END) as downclocks
FROM freq_data
GROUP BY core_type
ORDER BY core_type DESC

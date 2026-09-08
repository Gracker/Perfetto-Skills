-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 89b4d18013a6f905876e70327ad35d2b6b486969311b984b2eabdcf58eeffa90
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
LIMIT 50

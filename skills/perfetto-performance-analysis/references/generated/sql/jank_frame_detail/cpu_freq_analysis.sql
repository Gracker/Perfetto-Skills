-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 89b4d18013a6f905876e70327ad35d2b6b486969311b984b2eabdcf58eeffa90
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
freq_data AS (
  SELECT
    t.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    c.value as freq_khz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  LEFT JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
  WHERE t.name = 'cpufreq'
    AND c.ts >= ${start_ts}
    AND c.ts < ${end_ts}
)
SELECT
  core_type,
  ROUND(AVG(freq_khz) / 1000, 0) as avg_freq_mhz,
  ROUND(MAX(freq_khz) / 1000, 0) as max_freq_mhz,
  ROUND(MIN(freq_khz) / 1000, 0) as min_freq_mhz
FROM freq_data
GROUP BY core_type
ORDER BY core_type DESC

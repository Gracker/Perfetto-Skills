-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/device_state_timeline.skill.yaml
-- Source SHA-256: 706331c8ba61ce76147693d6cb6cdf6758bdfc7ecab0b035ab635b86002efd08
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH gpu_freq AS (
  SELECT
    c.ts,
    ct.name as counter_name,
    ROUND(c.value / 1000.0, 0) as freq_mhz,
    LAG(ROUND(c.value / 1000.0, 0)) OVER (PARTITION BY ct.name ORDER BY c.ts) as prev_freq_mhz
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*gpu_frequency*' OR ct.name GLOB '*gpu*freq*'
         OR ct.name GLOB '*GPU*Freq*' OR ct.name GLOB '*gpu*clock*')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts <= ${end_ts})
)
SELECT
  printf('%d', ts) as ts,
  counter_name,
  freq_mhz,
  prev_freq_mhz,
  ROUND(freq_mhz - COALESCE(prev_freq_mhz, freq_mhz), 0) as delta_mhz,
  CASE
    WHEN prev_freq_mhz IS NULL THEN 'initial'
    WHEN freq_mhz > prev_freq_mhz THEN 'boost'
    WHEN freq_mhz < prev_freq_mhz THEN 'throttle'
    ELSE 'stable'
  END as transition_type
FROM gpu_freq
WHERE prev_freq_mhz IS NULL
   OR freq_mhz != prev_freq_mhz
ORDER BY ts ASC
LIMIT 300

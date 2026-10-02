-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/cpu_module.skill.yaml
-- Source SHA-256: 9e8552f0cd155816d8cfb9eae5c9a2bfc2e33fc6f5b730b1afc204b95798e935

WITH freq_changes AS (
  SELECT
    cct.cpu as cpu,
    c.ts as ts,
    c.value as freq,
    LAG(c.value) OVER (PARTITION BY cct.cpu ORDER BY c.ts) AS prev_freq
  FROM cpu_counter_track cct
  JOIN counter c ON cct.id = c.track_id
  WHERE cct.name = 'cpufreq'
)
SELECT
  cpu,
  ts,
  CAST(freq / 1000 AS INTEGER) AS freq_mhz,
  CAST(prev_freq / 1000 AS INTEGER) AS prev_freq_mhz,
  CASE WHEN freq < prev_freq THEN 'throttle_down' ELSE 'throttle_up' END AS direction
FROM freq_changes
WHERE prev_freq IS NOT NULL
  AND ABS(freq - prev_freq) > 200000
ORDER BY ts DESC
LIMIT 50

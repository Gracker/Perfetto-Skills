-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  ct.core_type,
  COUNT(DISTINCT cct.cpu) as num_cores,
  ROUND(AVG(c.value) / 1000, 0) as avg_freq_mhz,
  ROUND(MAX(c.value) / 1000, 0) as max_freq_mhz,
  ROUND(MIN(c.value) / 1000, 0) as min_freq_mhz
FROM counter c
JOIN cpu_counter_track cct ON c.track_id = cct.id
JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
WHERE cct.name = 'cpufreq'
  AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY ct.core_type
ORDER BY max_freq_mhz DESC

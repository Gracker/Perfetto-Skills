-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 898b631aafbdad1f8c7fabc5e2a741fa750cf701ec82b9810adfd3e687b94431
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 6ebd984e1b34cb456d5fa410b4e2308e350c5854086ec1e06ff58b4c80c5ef4f
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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

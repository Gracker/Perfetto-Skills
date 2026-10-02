-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: dad4f0316164e1f40e731c8d36689fa5f09b8972bf70f5a4d48c894df90f3c91

SELECT
  cct.cpu as cpu_id,
  ROUND(MIN(c.value / 1000.0), 0) as min_freq_mhz,
  ROUND(MAX(c.value / 1000.0), 0) as max_freq_mhz,
  ROUND(AVG(c.value / 1000.0), 0) as avg_freq_mhz,
  COUNT(*) as sample_count,
  -- 相对节流比例：(max - min) / max * 100
  ROUND((MAX(c.value) - MIN(c.value)) * 100.0 / NULLIF(MAX(c.value), 0), 1) as throttle_ratio,
  CASE
    WHEN MIN(c.value) < MAX(c.value) * 0.3 THEN '大幅 DVFS 变化，原因未核验'
    WHEN MIN(c.value) < MAX(c.value) * 0.5 THEN 'DVFS 变化，原因未核验'
    WHEN MIN(c.value) < MAX(c.value) * 0.7 THEN 'DVFS 变化，原因未核验'
    ELSE '正常'
  END as throttling_status
FROM counter c
JOIN cpu_counter_track cct ON c.track_id = cct.id
WHERE cct.name = 'cpufreq'
  AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY cct.cpu
ORDER BY cpu_id

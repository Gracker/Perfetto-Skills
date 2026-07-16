-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/scheduler_module.skill.yaml
-- Source SHA-256: 170b97c3038eea5585806c1247f48db789f2b92d188f5c6f46e5b928afe06452
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
cpu_info AS (
  SELECT cpu_id as cpu, core_type
  FROM _cpu_topology
)
SELECT
  cct.cpu,
  COALESCE(ci.core_type, 'unknown') AS core_type,
  CAST(AVG(c.value) / 1000 AS INTEGER) AS avg_freq_mhz,
  CAST(MAX(c.value) / 1000 AS INTEGER) AS max_freq_mhz,
  CAST(MIN(c.value) / 1000 AS INTEGER) AS min_freq_mhz
FROM counter c
JOIN cpu_counter_track cct ON c.track_id = cct.id
LEFT JOIN cpu_info ci ON cct.cpu = ci.cpu
WHERE cct.name = 'cpufreq'
GROUP BY cct.cpu
ORDER BY cct.cpu

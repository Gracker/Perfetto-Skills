-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/scheduler_module.skill.yaml
-- Source SHA-256: 0eb2ad71f21998edd7e7c48853cb90b76d0a623ccf3936bee6aa61310d955a88
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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

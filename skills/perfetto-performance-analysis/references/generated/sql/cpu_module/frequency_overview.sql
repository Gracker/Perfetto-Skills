-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/cpu_module.skill.yaml
-- Source SHA-256: 4a9d6de50b0314b731792232ca2a3ac602c68e7c870a4e4a3d95f97d9f84a688

WITH
cpu_info AS (
  SELECT cpu_id as cpu, core_type as cluster
  FROM _cpu_topology
)
SELECT
  cct.cpu as cpu,
  COALESCE(ci.cluster, 'unknown') AS cluster,
  CAST(AVG(c.value) / 1000 AS INTEGER) AS avg_freq_mhz,
  CAST(MAX(c.value) / 1000 AS INTEGER) AS max_freq_mhz,
  CAST(MIN(c.value) / 1000 AS INTEGER) AS min_freq_mhz
FROM counter c
JOIN cpu_counter_track cct ON c.track_id = cct.id
LEFT JOIN cpu_info ci ON cct.cpu = ci.cpu
WHERE cct.name = 'cpufreq'
GROUP BY cct.cpu, ci.cluster
ORDER BY cct.cpu

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/cpu_module.skill.yaml
-- Source SHA-256: 4a9d6de50b0314b731792232ca2a3ac602c68e7c870a4e4a3d95f97d9f84a688

WITH
cpu_info AS (
  SELECT cpu_id as cpu, core_type as cluster
  FROM _cpu_topology
)
SELECT
  COALESCE(ci.cluster, 'unknown') AS cluster,
  COUNT(DISTINCT ss.cpu) AS core_count,
  CAST(SUM(ss.dur) / 1e9 AS REAL) AS total_time_sec,
  CAST(AVG(ss.dur) / 1e6 AS REAL) AS avg_slice_ms
FROM sched_slice ss
LEFT JOIN cpu_info ci ON ss.cpu = ci.cpu
GROUP BY cluster

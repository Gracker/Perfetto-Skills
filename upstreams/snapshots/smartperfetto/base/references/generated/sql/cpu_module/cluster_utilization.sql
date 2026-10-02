-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/cpu_module.skill.yaml
-- Source SHA-256: 9e8552f0cd155816d8cfb9eae5c9a2bfc2e33fc6f5b730b1afc204b95798e935

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

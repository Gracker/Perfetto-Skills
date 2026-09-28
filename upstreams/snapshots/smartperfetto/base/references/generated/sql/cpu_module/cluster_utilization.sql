-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/cpu_module.skill.yaml
-- Source SHA-256: d035f125f1bd29ac6f675796781f4037254da8283f6dc51f661b1b9e5afaa51e
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

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

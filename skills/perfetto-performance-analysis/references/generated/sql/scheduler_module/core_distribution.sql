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
  thread.name AS thread_name,
  CAST(SUM(CASE WHEN ci.core_type IN ('prime', 'big') THEN dur ELSE 0 END) * 100.0 / SUM(dur) AS INTEGER) AS big_core_pct,
  CAST(SUM(CASE WHEN ci.core_type = 'little' THEN dur ELSE 0 END) * 100.0 / SUM(dur) AS INTEGER) AS small_core_pct,
  CAST(SUM(dur) / 1e6 AS INTEGER) AS total_ms
FROM sched_slice
JOIN thread USING (utid)
LEFT JOIN cpu_info ci ON sched_slice.cpu = ci.cpu
WHERE thread.name IN ('RenderThread', 'main', 'UI Thread')
  OR thread.name LIKE '%${package}%'
GROUP BY utid
HAVING total_ms > 10
ORDER BY total_ms DESC

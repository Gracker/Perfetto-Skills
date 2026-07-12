-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/scheduler_module.skill.yaml
-- Source SHA-256: 170b97c3038eea5585806c1247f48db789f2b92d188f5c6f46e5b928afe06452
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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

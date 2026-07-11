-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_slice_analysis.skill.yaml
-- Source SHA-256: 2309b7c7da0ad9c74d1d781a1b5d0ea4b1466bc6f0ebd8757a467d36a7a59853
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH
target_threads AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.name as process_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*' OR '${package}' = ''
),
cpu_slices AS (
  SELECT
    ss.utid,
    ss.dur,
    ss.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type
  FROM sched_slice ss
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE (${start_ts} IS NULL OR ss.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ss.ts < ${end_ts})
    AND ss.utid IN (SELECT utid FROM target_threads)
)
SELECT
  tt.thread_name,
  tt.process_name,
  SUM(cs.dur) / 1e6 as total_cpu_ms,
  SUM(CASE WHEN cs.core_type IN ('prime', 'big') THEN cs.dur ELSE 0 END) / 1e6 as big_core_ms,
  SUM(CASE WHEN cs.core_type IN ('medium', 'little') THEN cs.dur ELSE 0 END) / 1e6 as little_core_ms,
  COUNT(*) as slice_count,
  AVG(cs.dur) / 1e6 as avg_slice_ms
FROM target_threads tt
LEFT JOIN cpu_slices cs ON tt.utid = cs.utid
GROUP BY tt.utid
HAVING total_cpu_ms > 0
ORDER BY total_cpu_ms DESC

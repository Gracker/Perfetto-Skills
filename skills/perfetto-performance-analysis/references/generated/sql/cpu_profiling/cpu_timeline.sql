-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: dce6ebab0c0096f73bc2707459de6af2cb7fefc55f171def6d1303d371c504ae

WITH
time_range AS (
  SELECT MIN(ts) as start_ts FROM sched_slice
),
cpu_by_second AS (
  SELECT
    CAST((ss.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INT) as second,
    ss.cpu,
    SUM(ss.dur) / 1e6 as runtime_ms
  FROM sched_slice ss
  GROUP BY CAST((ss.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INT), ss.cpu
)
SELECT
  second,
  COUNT(DISTINCT cpu) as active_cpus,
  SUM(runtime_ms) as total_cpu_ms,
  ROUND(SUM(runtime_ms) / COUNT(DISTINCT cpu), 1) as avg_per_cpu_ms
FROM cpu_by_second
GROUP BY second
ORDER BY second
LIMIT 60

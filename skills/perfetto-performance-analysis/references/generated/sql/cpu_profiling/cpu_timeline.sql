-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 55ba35f956b88823c9a3ffe665eaf555f382cf899a866b669ae5a7011ec4c639
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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

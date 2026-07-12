-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

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

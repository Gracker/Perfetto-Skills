-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 55ba35f956b88823c9a3ffe665eaf555f382cf899a866b669ae5a7011ec4c639
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
runnable_slices AS (
  SELECT
    ts.utid,
    ts.dur / 1e6 as latency_ms
  FROM thread_state ts
  WHERE
    ts.state = 'R'  -- Runnable but not running
    AND ts.dur > 0
),
thread_latency AS (
  SELECT
    t.name as thread_name,
    t.tid,
    p.name as process_name,
    COUNT(*) as runnable_count,
    SUM(rs.latency_ms) as total_latency_ms,
    AVG(rs.latency_ms) as avg_latency_ms,
    MAX(rs.latency_ms) as max_latency_ms
  FROM runnable_slices rs
  JOIN thread t ON rs.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE '${package}' = '' OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  GROUP BY rs.utid
)
SELECT
  thread_name,
  tid,
  process_name,
  runnable_count,
  ROUND(total_latency_ms, 2) as total_latency_ms,
  ROUND(avg_latency_ms, 3) as avg_latency_ms,
  ROUND(max_latency_ms, 2) as max_latency_ms
FROM thread_latency
WHERE total_latency_ms > 1  -- 至少 1ms 总延迟
ORDER BY total_latency_ms DESC
LIMIT 20

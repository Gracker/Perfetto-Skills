-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

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
  WHERE '${package}' = '' OR p.name GLOB '${package}*'
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

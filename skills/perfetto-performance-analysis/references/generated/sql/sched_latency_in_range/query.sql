-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/sched_latency_in_range.skill.yaml
-- Source SHA-256: 698297e54cca86ca36dc17117b27568195ae8f1b0f9d7c7e3c25922c969fc82c
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH target_threads AS (
  SELECT t.utid, t.name as thread_name, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (t.tid = p.pid OR t.name = 'RenderThread' OR t.name LIKE '%UI%')
),
runnable_states AS (
  SELECT tt.thread_name, ts.dur
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  WHERE (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND ts.state = 'R'  -- Runnable but not running
    AND ts.dur > 10000  -- > 10us to be meaningful
)
SELECT
  thread_name,
  COUNT(*) as runnable_count,
  ROUND(SUM(dur) / 1e6, 2) as total_runnable_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_latency_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_latency_ms,
  SUM(CASE WHEN dur > 2000000 THEN 1 ELSE 0 END) as long_wait_count
FROM runnable_states
GROUP BY thread_name
HAVING total_runnable_ms > 0.1
ORDER BY total_runnable_ms DESC

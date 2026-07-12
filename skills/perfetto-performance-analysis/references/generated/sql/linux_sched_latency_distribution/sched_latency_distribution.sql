-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_sched_latency_distribution.skill.yaml
-- Source SHA-256: b193794805d2765d8923aeb693fe88709520ebe0d0b3c9ff5eb44a2e0a9afe73
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM thread_state)) AS end_ts
),
latency AS (
  SELECT
    p.name AS process_name,
    COALESCE(t.name, printf('tid:%d', t.tid)) AS thread_name,
    sl.latency_dur
  FROM sched_latency_for_running_interval sl
  JOIN thread_state ts ON sl.thread_state_id = ts.id
  JOIN thread t ON sl.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
    AND ts.ts >= i.start_ts
    AND ts.ts < i.end_ts
    AND sl.latency_dur > 10000
)
SELECT
  process_name,
  thread_name,
  COUNT(*) AS runnable_count,
  ROUND(SUM(latency_dur) / 1e6, 2) AS total_latency_ms,
  ROUND(AVG(latency_dur) / 1e6, 2) AS avg_latency_ms,
  ROUND(PERCENTILE(latency_dur, 0.95) / 1e6, 2) AS p95_latency_ms,
  ROUND(MAX(latency_dur) / 1e6, 2) AS max_latency_ms,
  SUM(CASE WHEN latency_dur > 8000000 THEN 1 ELSE 0 END) AS severe_waits
FROM latency
GROUP BY process_name, thread_name
HAVING total_latency_ms > 0.1
ORDER BY severe_waits DESC, total_latency_ms DESC
LIMIT 100

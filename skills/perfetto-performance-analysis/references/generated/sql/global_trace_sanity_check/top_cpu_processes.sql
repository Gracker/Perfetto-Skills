-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 3c4b708b7b84c9206463877bf914275bb2d48df15eef7c821ebe6eeaf4a8e263
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH
raw_input AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS raw_start_ts,
    COALESCE(${end_ts}, trace_end()) AS raw_end_ts,
    MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 100) AS max_rows
),
input AS (
  SELECT
    MIN(raw_start_ts, raw_end_ts) AS start_ts,
    MAX(raw_start_ts, raw_end_ts) AS end_ts,
    max_rows
  FROM raw_input
),
normalized AS (
  SELECT
    ss.ts,
    IIF(ss.dur = -1, trace_end() - ss.ts, ss.dur) AS effective_dur,
    ss.utid,
    COALESCE(p.upid, -ss.utid) AS process_key,
    p.upid,
    COALESCE(p.pid, t.tid) AS pid,
    COALESCE(p.name, t.name, '<kernel thread>') AS process_name
  FROM sched_slice ss
  LEFT JOIN thread t ON ss.utid = t.utid
  LEFT JOIN process p ON t.upid = p.upid
  WHERE COALESCE(t.is_idle, 0) = 0
),
overlapped AS (
  SELECT
    n.*,
    MAX(n.ts, input.start_ts) AS overlap_start_ts,
    MIN(n.ts + n.effective_dur, input.end_ts) - MAX(n.ts, input.start_ts) AS overlap_dur
  FROM normalized n, input
  WHERE n.effective_dur > 0
    AND n.ts < input.end_ts
    AND n.ts + n.effective_dur > input.start_ts
)
SELECT
  ROUND(SUM(overlap_dur) / 1e6, 2) AS cpu_time_ms,
  COUNT(*) AS sched_slices,
  process_name,
  process_key,
  upid,
  pid,
  COUNT(DISTINCT utid) AS thread_count,
  printf('%d', MIN(overlap_start_ts)) AS first_ts
FROM overlapped
GROUP BY process_key, upid, pid, process_name
ORDER BY SUM(overlap_dur) DESC
LIMIT (SELECT max_rows FROM input)

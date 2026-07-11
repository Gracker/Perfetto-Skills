-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 082c5e5e00286a42ebf2cb10e6d0305f0d94f83c2f64eb7baef061951d49dec8
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
    ts.ts,
    IIF(ts.dur = -1, trace_end() - ts.ts, ts.dur) AS effective_dur,
    p.upid,
    p.pid,
    t.utid,
    t.tid,
    COALESCE(p.name, '<kernel>') AS process_name,
    COALESCE(t.name, '<unknown thread>') AS thread_name
  FROM thread_state ts
  LEFT JOIN thread t ON ts.utid = t.utid
  LEFT JOIN process p ON t.upid = p.upid
  WHERE ts.state IN ('R', 'R+')
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
  ROUND(SUM(overlap_dur) / 1e6, 2) AS total_runnable_wait_ms,
  ROUND(MAX(overlap_dur) / 1e6, 2) AS max_runnable_wait_ms,
  COUNT(*) AS events,
  process_name,
  thread_name,
  upid,
  pid,
  utid,
  tid,
  printf('%d', MIN(overlap_start_ts)) AS first_ts
FROM overlapped
GROUP BY upid, pid, utid, tid, process_name, thread_name
ORDER BY SUM(overlap_dur) DESC, MAX(overlap_dur) DESC
LIMIT (SELECT max_rows FROM input)

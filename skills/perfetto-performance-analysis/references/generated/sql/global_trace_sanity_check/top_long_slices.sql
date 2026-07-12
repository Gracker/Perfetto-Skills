-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 3c4b708b7b84c9206463877bf914275bb2d48df15eef7c821ebe6eeaf4a8e263
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

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
    s.ts,
    IIF(s.dur = -1, trace_end() - s.ts, s.dur) AS effective_dur,
    COALESCE(s.name, '<unnamed>') AS slice_name,
    COALESCE(p.name, pp.name, tr.name, '<no process>') AS process_name,
    COALESCE(t.name, pt.name, tr.name, '<no thread>') AS thread_name
  FROM slice s
  LEFT JOIN track tr ON s.track_id = tr.id
  LEFT JOIN thread_track tt ON s.track_id = tt.id
  LEFT JOIN thread t ON tt.utid = t.utid
  LEFT JOIN process p ON t.upid = p.upid
  LEFT JOIN process_track pt ON s.track_id = pt.id
  LEFT JOIN process pp ON pt.upid = pp.upid
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
  printf('%d', overlap_start_ts) AS ts,
  printf('%d', overlap_dur) AS dur_ns,
  ROUND(overlap_dur / 1e6, 2) AS duration_ms,
  ROUND(overlap_dur / 1e6, 2) AS overlap_ms,
  ROUND(effective_dur / 1e6, 2) AS slice_total_ms,
  printf('%d', ts) AS slice_start_ts,
  printf('%d', effective_dur) AS slice_dur_ns,
  slice_name,
  process_name,
  thread_name
FROM overlapped
ORDER BY overlap_dur DESC, effective_dur DESC
LIMIT (SELECT max_rows FROM input)

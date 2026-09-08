-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/longest_process_slices.skill.yaml
-- Source SHA-256: afd2f8caa3379888693e359840046ddb1c854202cdfe90578fc67ddd9a4916a8
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
    s.id AS slice_id,
    s.ts,
    IIF(s.dur = -1, trace_end() - s.ts, s.dur) AS effective_dur,
    COALESCE(NULLIF(TRIM(s.name), ''), '<unnamed>') AS slice_name,
    CASE
      WHEN tt.id IS NOT NULL THEN COALESCE(NULLIF(TRIM(p.name), ''), '<unnamed process>')
      ELSE COALESCE(NULLIF(TRIM(pp.name), ''), '<unnamed process>')
    END AS process_name,
    CASE
      WHEN tt.id IS NOT NULL THEN COALESCE(NULLIF(TRIM(t.name), ''), '<unnamed thread>')
      ELSE '<process track>'
    END AS thread_name,
    CASE
      WHEN tt.id IS NOT NULL THEN 'thread_track'
      ELSE 'process_track'
    END AS track_scope
  FROM slice s
  LEFT JOIN thread_track tt ON s.track_id = tt.id
  LEFT JOIN thread t ON tt.utid = t.utid
  LEFT JOIN process p ON t.upid = p.upid
  LEFT JOIN process_track pt ON s.track_id = pt.id
  LEFT JOIN process pp ON pt.upid = pp.upid
  WHERE p.upid IS NOT NULL OR pp.upid IS NOT NULL
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
  ROUND(overlap_dur / 1e6, 6) AS duration_ms,
  ROUND(overlap_dur / 1e6, 6) AS overlap_ms,
  ROUND(effective_dur / 1e6, 6) AS slice_total_ms,
  printf('%d', ts) AS slice_start_ts,
  slice_id,
  printf('%d', effective_dur) AS slice_dur_ns,
  slice_name,
  process_name,
  thread_name,
  track_scope
FROM overlapped
ORDER BY overlap_dur DESC, effective_dur DESC, ts ASC, slice_id ASC
LIMIT (SELECT max_rows FROM input)

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: d2f99680715212f30bafe86e1323d04cb469e5582ac89cad1e8c7b48f92e9c2e
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

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
candidates AS (
  SELECT
    MAX(ts, input.start_ts) AS overlap_ts,
    MIN(ts + IIF(dur = -1, trace_end() - ts, dur), input.end_ts)
      - MAX(ts, input.start_ts) AS overlap_dur,
    COALESCE(name, '<unnamed slice>') AS slice_name,
    COALESCE(process_name, '<unnamed process>') AS process_name,
    COALESCE(thread_name, '<unnamed thread>') AS thread_name,
    upid,
    utid
  FROM thread_slice, input
  WHERE ts < input.end_ts
    AND ts + IIF(dur = -1, trace_end() - ts, dur) > input.start_ts
    AND (
      lower(COALESCE(name, '')) GLOB '*camera*'
      OR lower(COALESCE(name, '')) GLOB '*camx*'
      OR lower(COALESCE(name, '')) GLOB '*mtkcam*'
      OR lower(COALESCE(name, '')) GLOB '*capture*'
      OR lower(COALESCE(name, '')) GLOB '*preview*'
    )
)
SELECT
  printf('%d', overlap_ts) AS ts,
  printf('%d', overlap_dur) AS dur_ns,
  slice_name,
  process_name,
  thread_name,
  upid,
  utid,
  'thread_slice' AS source,
  'Slice names are implementation-specific candidates and require identity/anchor verification.' AS limitation
FROM candidates, input
WHERE overlap_dur > 0
ORDER BY overlap_dur DESC
LIMIT (SELECT max_rows FROM input)

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
identity_count AS (
  SELECT
    (SELECT COUNT(*)
     FROM process
     WHERE lower(COALESCE(name, '')) GLOB '*camera*'
        OR lower(COALESCE(name, '')) GLOB '*camx*'
        OR lower(COALESCE(name, '')) GLOB '*mtkcam*')
    +
    (SELECT COUNT(*)
     FROM thread
     WHERE lower(COALESCE(name, '')) GLOB '*camera*'
        OR lower(COALESCE(name, '')) GLOB '*camx*'
        OR lower(COALESCE(name, '')) GLOB '*mtkcam*') AS candidate_count
),
slice_count AS (
  SELECT COUNT(*) AS candidate_count
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
),
binder_count AS (
  SELECT COUNT(*) AS candidate_count
  FROM android_binder_txns, input
  WHERE client_ts >= input.start_ts
    AND client_ts < input.end_ts
    AND (
      lower(COALESCE(client_process, '')) GLOB '*camera*'
      OR lower(COALESCE(server_process, '')) GLOB '*camera*'
      OR lower(COALESCE(client_process, '')) GLOB '*camx*'
      OR lower(COALESCE(server_process, '')) GLOB '*camx*'
      OR lower(COALESCE(client_process, '')) GLOB '*mtkcam*'
      OR lower(COALESCE(server_process, '')) GLOB '*mtkcam*'
    )
),
scheduler_count AS (
  SELECT COUNT(*) AS candidate_count
  FROM sched_slice, input
  WHERE ts < input.end_ts
    AND ts + IIF(dur = -1, trace_end() - ts, dur) > input.start_ts
),
frequency_count AS (
  SELECT COUNT(*) AS candidate_count
  FROM cpu_frequency_counters, input
  WHERE ts < input.end_ts
    AND ts + IIF(dur = -1, trace_end() - ts, dur) > input.start_ts
),
frame_count AS (
  SELECT COUNT(*) AS candidate_count
  FROM actual_frame_timeline_slice, input
  WHERE ts < input.end_ts
    AND ts + IIF(dur = -1, trace_end() - ts, dur) > input.start_ts
),
buffer_memory_count AS (
  SELECT
    (SELECT COUNT(*)
     FROM android_dmabuf_allocs, input
     WHERE ts >= input.start_ts
       AND ts < input.end_ts)
    +
    (SELECT COUNT(*)
     FROM counter AS c
     JOIN thread_counter_track AS tct ON c.track_id = tct.id
     CROSS JOIN input
     WHERE tct.name GLOB 'mem.ion_change*'
       AND c.ts >= input.start_ts
       AND c.ts < input.end_ts) AS candidate_count
),
pixel_count AS (
  SELECT COUNT(*) AS candidate_count
  FROM pixel_camera_frames, input
  WHERE ts >= input.start_ts AND ts < input.end_ts
)
SELECT
  'camera_process_thread_identity' AS evidence_family,
  CASE WHEN candidate_count > 0 THEN 'available' ELSE 'missing' END AS status,
  candidate_count AS row_count,
  'process,thread' AS source,
  'Name-based identity candidates are not proof of a specific Camera milestone.' AS limitation
FROM identity_count
UNION ALL
SELECT
  'camera_slice_candidates',
  CASE WHEN candidate_count > 0 THEN 'vendor_specific' ELSE 'missing' END,
  candidate_count,
  'thread_slice',
  'Slice names are implementation-specific candidates and require identity/anchor verification.'
FROM slice_count
UNION ALL
SELECT
  'binder_transactions',
  CASE WHEN candidate_count > 0 THEN 'available' ELSE 'missing' END,
  candidate_count,
  'android_binder_txns',
  'Binder rows provide cross-process correlation; interface names and endpoints must still be verified.'
FROM binder_count
UNION ALL
SELECT
  'scheduler_context',
  CASE WHEN candidate_count > 0 THEN 'available' ELSE 'missing' END,
  candidate_count,
  'sched_slice',
  'Scheduler rows provide execution context only after Camera thread identity is established.'
FROM scheduler_count
UNION ALL
SELECT
  'cpu_frequency_context',
  CASE WHEN candidate_count > 0 THEN 'available' ELSE 'missing' END,
  candidate_count,
  'cpu_frequency_counters',
  'CPU-frequency rows provide system context and do not by themselves attribute Camera latency.'
FROM frequency_count
UNION ALL
SELECT
  'frame_timeline',
  CASE WHEN candidate_count > 0 THEN 'available' ELSE 'missing' END,
  candidate_count,
  'actual_frame_timeline_slice',
  'FrameTimeline can support presentation correlation only after preview surface identity is established.'
FROM frame_count
UNION ALL
SELECT
  'dmabuf_allocations',
  CASE WHEN candidate_count > 0 THEN 'available' ELSE 'missing' END,
  candidate_count,
  'android_dmabuf_allocs; counter + thread_counter_track (mem.ion_change*)',
  'DMA-BUF and legacy ION signed deltas cover only observed events; they are not retained memory or leak proof.'
FROM buffer_memory_count
UNION ALL
SELECT
  'pixel_camera_frames',
  CASE WHEN candidate_count > 0 THEN 'vendor_specific' ELSE 'missing' END,
  candidate_count,
  'pixel_camera_frames',
  'pixel.camera is an optional Pixel slice parser, not a portable Android Camera contract.'
FROM pixel_count

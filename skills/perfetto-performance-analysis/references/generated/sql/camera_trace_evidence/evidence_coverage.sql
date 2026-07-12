-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: e04e0e2abc55ba999b714a2c10b4ef880e1770e26691a3ea05fa412cf78ec05b
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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
dmabuf_count AS (
  SELECT COUNT(*) AS candidate_count
  FROM android_dmabuf_allocs, input
  WHERE ts >= input.start_ts AND ts < input.end_ts
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
  'android_dmabuf_allocs',
  'DMA-BUF allocation deltas are memory evidence; they do not alone prove a leak.'
FROM dmabuf_count
UNION ALL
SELECT
  'pixel_camera_frames',
  CASE WHEN candidate_count > 0 THEN 'vendor_specific' ELSE 'missing' END,
  candidate_count,
  'pixel_camera_frames',
  'pixel.camera is an optional Pixel slice parser, not a portable Android Camera contract.'
FROM pixel_count

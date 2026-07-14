-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: d2f99680715212f30bafe86e1323d04cb469e5582ac89cad1e8c7b48f92e9c2e
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

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
events AS (
  SELECT
    alloc.ts,
    alloc.buf_size AS signed_bytes,
    COALESCE(alloc.process_name, '<unnamed process>') AS process_name,
    alloc.upid,
    alloc.pid,
    'dmabuf' AS memory_source
  FROM android_dmabuf_allocs AS alloc
  CROSS JOIN input
  WHERE alloc.ts >= input.start_ts
    AND alloc.ts < input.end_ts
    AND (
      lower(COALESCE(alloc.process_name, '')) GLOB '*camera*'
      OR lower(COALESCE(alloc.process_name, '')) GLOB '*camx*'
      OR lower(COALESCE(alloc.process_name, '')) GLOB '*mtkcam*'
      OR lower(COALESCE(alloc.thread_name, '')) GLOB '*camera*'
      OR lower(COALESCE(alloc.thread_name, '')) GLOB '*camx*'
      OR lower(COALESCE(alloc.thread_name, '')) GLOB '*mtkcam*'
    )
  UNION ALL
  SELECT
    c.ts,
    CAST(c.value AS INTEGER) AS signed_bytes,
    COALESCE(p.name, '<unnamed process>') AS process_name,
    p.upid,
    p.pid,
    'legacy_ion' AS memory_source
  FROM counter AS c
  JOIN thread_counter_track AS tct ON c.track_id = tct.id
  JOIN thread AS th ON th.utid = tct.utid
  LEFT JOIN process AS p ON p.upid = th.upid
  CROSS JOIN input
  WHERE tct.name GLOB 'mem.ion_change*'
    AND c.ts >= input.start_ts
    AND c.ts < input.end_ts
    AND (
      lower(COALESCE(p.name, '')) GLOB '*camera*'
      OR lower(COALESCE(p.name, '')) GLOB '*camx*'
      OR lower(COALESCE(p.name, '')) GLOB '*mtkcam*'
      OR lower(COALESCE(th.name, '')) GLOB '*camera*'
      OR lower(COALESCE(th.name, '')) GLOB '*camx*'
      OR lower(COALESCE(th.name, '')) GLOB '*mtkcam*'
    )
)
SELECT
  process_name,
  upid,
  pid,
  memory_source,
  SUM(CASE WHEN signed_bytes > 0 THEN 1 ELSE 0 END) AS allocation_count,
  SUM(CASE WHEN signed_bytes > 0 THEN signed_bytes ELSE 0 END) AS allocation_bytes,
  -SUM(CASE WHEN signed_bytes < 0 THEN signed_bytes ELSE 0 END) AS release_bytes,
  SUM(signed_bytes) AS observed_net_delta_bytes,
  MAX(ABS(signed_bytes)) AS peak_event_bytes,
  CASE memory_source
    WHEN 'dmabuf' THEN 'android_dmabuf_allocs'
    ELSE 'counter + thread_counter_track (mem.ion_change*)'
  END AS source,
  'DMA-BUF (android_dmabuf_allocs) and legacy ION (counter + thread_counter_track mem.ion_change*) signed deltas cover only events inside this selected window; allocations may predate it and releases may occur later, so this is not retained memory or leak proof.' AS limitation
FROM events
GROUP BY process_name, upid, pid, memory_source
ORDER BY ABS(SUM(signed_bytes)) DESC, allocation_bytes DESC
LIMIT (SELECT max_rows FROM input)

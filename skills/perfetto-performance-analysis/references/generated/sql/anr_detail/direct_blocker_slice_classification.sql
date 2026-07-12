-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} AS start_ts,
    ${anr_ts} AS end_ts,
    ${timeout_ns} AS window_ns
),
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
),
render_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.name = 'RenderThread'
  LIMIT 1
),
main_slices AS (
  SELECT
    LOWER(s.name) AS slice_name,
    MIN(CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END, aw.end_ts) - MAX(s.ts, aw.start_ts) AS clipped_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN main_thread mt ON tt.utid = mt.utid
  CROSS JOIN anr_window aw
  WHERE s.ts < aw.end_ts
    AND (CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END) > aw.start_ts
),
render_slices AS (
  SELECT
    LOWER(s.name) AS slice_name,
    MIN(CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END, aw.end_ts) - MAX(s.ts, aw.start_ts) AS clipped_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN render_thread rt ON tt.utid = rt.utid
  CROSS JOIN anr_window aw
  WHERE s.ts < aw.end_ts
    AND (CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END) > aw.start_ts
),
metrics AS (
  SELECT
    COALESCE((SELECT SUM(clipped_ns) FROM main_slices
      WHERE slice_name GLOB '*sqlite*'
        OR slice_name GLOB '*database*'
        OR slice_name GLOB '*fsync*'
        OR slice_name GLOB '*fileio*'
        OR slice_name GLOB '*file_io*'
        OR slice_name GLOB '*disk*'
        OR slice_name GLOB '*sharedpreferences*'
        OR slice_name GLOB '*queuedwork*'), 0) AS main_io_slice_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_slices
      WHERE slice_name GLOB '*gc*'
        OR slice_name GLOB '*garbage*'
        OR slice_name GLOB '*waitforgctocomplete*'
        OR slice_name GLOB '*suspend*'), 0) AS gc_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_slices
      WHERE slice_name GLOB '*syncanddraw*'
        OR slice_name GLOB '*waitforfence*'
        OR slice_name GLOB '*dequeuebuffer*'
        OR slice_name GLOB '*egl*'), 0) +
    COALESCE((SELECT SUM(clipped_ns) FROM render_slices
      WHERE slice_name GLOB '*syncanddraw*'
        OR slice_name GLOB '*waitforfence*'
        OR slice_name GLOB '*dequeuebuffer*'
        OR slice_name GLOB '*drawframe*'
        OR slice_name GLOB '*syncframestate*'), 0) AS render_wait_ns
),
candidates AS (
  SELECT 'db_or_file_io_slice' AS direct_blocker_type, main_io_slice_ns AS evidence_ns,
    'main_thread_slice' AS evidence_source,
    CASE WHEN main_io_slice_ns > 500000000 THEN 'medium' ELSE 'low' END AS confidence,
    'app_candidate_needs_window_context' AS root_cause_boundary,
    '需要确认该 IO slice 与 ANR 前窗口重叠，并结合系统 IO 压力判断是否被放大' AS next_evidence_needed
  FROM metrics WHERE main_io_slice_ns > 0
  UNION ALL
  SELECT 'render_or_fence_wait', render_wait_ns, 'main_or_render_thread_slice',
    CASE WHEN render_wait_ns > 500000000 THEN 'medium' ELSE 'low' END,
    'needs_render_sf_evidence',
    '需要 RenderThread、SurfaceFlinger、fence/buffer queue 证据闭环'
  FROM metrics WHERE render_wait_ns > 0
  UNION ALL
  SELECT 'gc_or_stw_wait', gc_wait_ns, 'main_thread_slice',
    CASE WHEN gc_wait_ns > 500000000 THEN 'medium' ELSE 'low' END,
    'needs_memory_gc_evidence',
    '需要 GC/logcat、PSI memory、LMK/OOM 或多线程暂停证据确认'
  FROM metrics WHERE gc_wait_ns > 0
)
SELECT
  direct_blocker_type,
  ROUND(evidence_ns / 1e6, 2) AS evidence_ms,
  ROUND(100.0 * evidence_ns / NULLIF((SELECT window_ns FROM anr_window), 0), 1) AS pct_of_timeout,
  evidence_source,
  confidence,
  root_cause_boundary,
  next_evidence_needed
FROM candidates
ORDER BY
  CASE confidence WHEN 'medium' THEN 1 ELSE 2 END,
  evidence_ns DESC
LIMIT 5

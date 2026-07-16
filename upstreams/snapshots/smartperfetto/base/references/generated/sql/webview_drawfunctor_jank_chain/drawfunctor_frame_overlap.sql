-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/webview_drawfunctor_jank_chain.skill.yaml
-- Source SHA-256: d0794e39385b8e2f575eebff3c0229ba4ca0b468c5845b371ac3187f521f2c7a
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
webview_processes AS (
  SELECT DISTINCT p.upid
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*' OR p.name GLOB '*webview*' OR p.name GLOB '*sandboxed_process*')
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND (
      t.name GLOB '*CrRendererMain*' OR t.name GLOB '*Compositor*' OR
      s.name GLOB '*DrawGL*' OR s.name GLOB '*DrawFn_DrawGL*' OR
      s.name GLOB '*DrawFunctor*' OR s.name GLOB '*AwDrawFn*'
    )
),
frame_budget AS (
  SELECT COALESCE(
    (SELECT CAST(PERCENTILE(dur, 0.5) AS INTEGER)
     FROM actual_frame_timeline_slice
     WHERE dur BETWEEN 5000000 AND 50000000),
    16666667
  ) AS budget_ns
),
webview_slices AS (
  SELECT
    s.id,
    s.ts,
    s.dur,
    s.ts + s.dur AS ts_end,
    s.name AS slice_name,
    COALESCE(t.name, '<unnamed>') AS thread_name,
    p.name AS process_name,
    p.upid,
    CASE
      WHEN s.name GLOB '*DrawGL*' OR s.name GLOB '*DrawFn_DrawGL*' OR s.name GLOB '*DrawFunctor*' OR s.name GLOB '*AwDrawFn*' THEN 'host_renderthread_functor'
      WHEN t.name GLOB '*CrRendererMain*' OR s.name GLOB '*Blink*' OR s.name GLOB '*Chromium*' THEN 'chromium_render_main'
      WHEN s.name GLOB '*v8*' OR s.name GLOB '*V8*' OR s.name GLOB '*JavaScript*' THEN 'javascript_v8'
      WHEN t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*' THEN 'chromium_compositor'
      ELSE 'webview_other'
    END AS phase
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*' OR p.name GLOB '*webview*' OR p.name GLOB '*sandboxed_process*')
    AND p.upid IN (SELECT upid FROM webview_processes)
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND s.dur > 0
    AND (
      t.name GLOB '*CrRendererMain*' OR t.name GLOB '*Compositor*' OR
      s.name GLOB '*DrawGL*' OR s.name GLOB '*DrawFn_DrawGL*' OR s.name GLOB '*DrawFunctor*' OR s.name GLOB '*AwDrawFn*' OR
      s.name GLOB '*Blink*' OR s.name GLOB '*Chromium*' OR
      s.name GLOB '*v8*' OR s.name GLOB '*V8*' OR s.name GLOB '*JavaScript*'
    )
),
frames AS (
  SELECT
    a.ts,
    a.dur,
    a.ts + a.dur AS ts_end,
    COALESCE(a.display_frame_token, a.surface_frame_token) AS frame_id,
    COALESCE(a.jank_type, 'None') AS jank_type,
    a.upid
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
    AND a.ts >= i.start_ts
    AND a.ts < i.end_ts
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
overlaps AS (
  SELECT
    ws.*,
    f.frame_id,
    f.dur AS frame_dur,
    f.jank_type,
    MAX(0, MIN(ws.ts_end, f.ts_end) - MAX(ws.ts, f.ts)) AS overlap_ns
  FROM webview_slices ws
  JOIN frames f ON f.upid = ws.upid
    AND ws.ts < f.ts_end
    AND ws.ts_end > f.ts
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur_ns,
  ROUND(dur / 1e6, 2) AS dur_ms,
  phase,
  slice_name,
  thread_name,
  process_name,
  COUNT(DISTINCT frame_id) AS overlapped_frames,
  SUM(CASE WHEN jank_type != 'None' OR frame_dur > (SELECT budget_ns * 1.5 FROM frame_budget) THEN 1 ELSE 0 END) AS janky_frames,
  ROUND(MAX(overlap_ns) / 1e6, 2) AS max_overlap_ms,
  ROUND(MAX(frame_dur) / 1e6, 2) AS max_frame_dur_ms
FROM overlaps
WHERE overlap_ns > 0
GROUP BY id, ts, dur, phase, slice_name, thread_name, process_name
HAVING janky_frames > 0 OR dur_ms > 8
ORDER BY janky_frames DESC, dur_ms DESC
LIMIT 100

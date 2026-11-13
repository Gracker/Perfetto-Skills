-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/webview_drawfunctor_jank_chain.skill.yaml
-- Source SHA-256: f955143f2e4366b68abd38648cac6d652dbd08240aecca385340a151f984ca93

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
-- WEBVIEW_CHROMIUM_SCOPE_CTES_BEGIN
functor_events AS (
  SELECT s.id, s.track_id, s.ts, s.dur,
    CASE
      WHEN s.name GLOB 'WebViewFunctor::postDraw*' OR s.name GLOB '*DrawFn_PostDraw*' THEN 'host_renderthread_functor_post_draw'
      WHEN s.name GLOB 'WebViewFunctor::sync*' OR s.name GLOB '*DrawFn_OnSync*' THEN 'host_renderthread_functor_sync'
      WHEN s.name GLOB 'WebViewFunctor::draw[GgVv][LlKk]*'
        OR s.name GLOB '*DrawFn_Draw[GV][Llk]*'
        OR s.name GLOB 'DrawGL*' OR s.name GLOB 'DrawVk*'
        OR s.name GLOB '*DrawFunctor*'
        OR s.name GLOB 'AwDrawFnImpl::Draw[GV][Llk]*'
        THEN 'host_renderthread_functor'
    END AS phase
  FROM slice s
  CROSS JOIN input i
  WHERE s.ts >= i.start_ts AND s.ts < i.end_ts AND s.dur > 0
),
functor_slices AS (
  -- Nested wrappers describe one invocation, not additional output frames.
  SELECT event.*
  FROM functor_events event
  WHERE event.phase IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM functor_events wrapper
      WHERE wrapper.track_id = event.track_id AND wrapper.phase = event.phase
        AND wrapper.ts <= event.ts
        AND wrapper.ts + wrapper.dur >= event.ts + event.dur
        AND (wrapper.dur > event.dur OR (wrapper.dur = event.dur AND wrapper.id < event.id))
    )
),
scoped_processes AS (
  SELECT p.upid, p.name AS process_name
  FROM process p
  CROSS JOIN input i
  WHERE p.name IS NOT NULL
    AND (
      (i.target_process <> '' AND (p.name = i.target_process OR p.name GLOB i.target_process || ':*'))
      OR (
        i.target_process = ''
        AND (
          p.name GLOB '*webview*'
          OR p.name GLOB '*sandboxed_process*'
          OR p.upid IN (
            SELECT t.upid
            FROM slice s
            JOIN thread_track tt ON s.track_id = tt.id
            JOIN thread t ON tt.utid = t.utid
            CROSS JOIN input identity_window
            WHERE s.ts >= identity_window.start_ts
              AND s.ts < identity_window.end_ts
              AND (
                t.name GLOB '*CrRendererMain*'
                OR t.name GLOB 'VizCompositorThread*'
                OR s.id IN (SELECT id FROM functor_slices)
                OR s.name GLOB '*Blink*'
                OR s.name GLOB '*Chromium*'
              )
          )
        )
      )
    )
),
chromium_identity AS (
  SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM slice s
    JOIN thread_track tt ON s.track_id = tt.id
    JOIN thread t ON tt.utid = t.utid
    JOIN scoped_processes sp ON t.upid = sp.upid
    CROSS JOIN input i
    WHERE s.ts >= i.start_ts
      AND s.ts < i.end_ts
      AND (
        t.name GLOB '*CrRendererMain*'
        OR t.name GLOB 'VizCompositorThread*'
        OR s.name GLOB '*Blink*'
        OR s.name GLOB '*Chromium*'
      )
  ) THEN 1 ELSE 0 END AS has_chromium_identity
),
webview_processes AS (
  SELECT DISTINCT p.upid
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  JOIN scoped_processes sp ON p.upid = sp.upid
  CROSS JOIN input i
  CROSS JOIN chromium_identity ci
  WHERE s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND (
      t.name GLOB '*CrRendererMain*' OR
      s.id IN (SELECT id FROM functor_slices) OR
      (
        ci.has_chromium_identity = 1
        AND (t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*')
      )
    )
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
      WHEN fs.phase IS NOT NULL THEN fs.phase
      WHEN t.name GLOB '*CrRendererMain*' OR s.name GLOB '*Blink*' OR s.name GLOB '*Chromium*' THEN 'chromium_render_main'
      WHEN s.name GLOB '*v8*' OR s.name GLOB '*V8*' OR s.name GLOB '*JavaScript*' THEN 'javascript_v8'
      WHEN ci.has_chromium_identity = 1 AND (t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*') THEN 'chromium_compositor'
      ELSE 'webview_other'
    END AS phase
  FROM slice s
  LEFT JOIN functor_slices fs ON fs.id = s.id
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  CROSS JOIN chromium_identity ci
  WHERE p.upid IN (SELECT upid FROM webview_processes)
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND s.dur > 0
    AND (
      t.name GLOB '*CrRendererMain*' OR
      fs.phase IS NOT NULL OR
      s.name GLOB '*Blink*' OR s.name GLOB '*Chromium*' OR
      s.name GLOB '*v8*' OR s.name GLOB '*V8*' OR s.name GLOB '*JavaScript*' OR
      (
        ci.has_chromium_identity = 1
        AND (t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*')
      )
    )
),
-- WEBVIEW_CHROMIUM_SCOPE_CTES_END
frame_budget AS (
  SELECT COALESCE(
    (SELECT CAST(PERCENTILE(dur, 50) AS INTEGER)
     FROM actual_frame_timeline_slice
     WHERE dur BETWEEN 5000000 AND 50000000),
    16666667
  ) AS budget_ns
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
  WHERE (i.target_process = '' OR p.name = i.target_process OR p.name GLOB i.target_process || ':*')
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

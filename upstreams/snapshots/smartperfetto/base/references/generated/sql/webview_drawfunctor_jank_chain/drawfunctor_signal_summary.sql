-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/webview_drawfunctor_jank_chain.skill.yaml
-- Source SHA-256: d0794e39385b8e2f575eebff3c0229ba4ca0b468c5845b371ac3187f521f2c7a
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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
webview_slices AS (
  SELECT
    s.ts,
    s.dur,
    s.name AS slice_name,
    COALESCE(t.name, '<unnamed>') AS thread_name,
    p.name AS process_name,
    CASE
      WHEN s.name GLOB '*DrawGL*' OR s.name GLOB '*DrawFn_DrawGL*' OR s.name GLOB '*DrawFunctor*' OR s.name GLOB '*AwDrawFn*' THEN 'host_renderthread_functor'
      WHEN t.name GLOB '*CrRendererMain*' OR s.name GLOB '*Blink*' OR s.name GLOB '*Chromium*' THEN 'chromium_render_main'
      WHEN s.name GLOB '*v8*' OR s.name GLOB '*V8*' OR s.name GLOB '*JavaScript*' THEN 'javascript_v8'
      WHEN t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*' THEN 'chromium_compositor'
      ELSE 'webview_other'
    END AS phase,
    ROUND(s.dur / 1e6, 2) AS dur_ms
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
)
SELECT
  phase,
  process_name,
  thread_name,
  COUNT(*) AS slice_count,
  ROUND(AVG(dur_ms), 2) AS avg_dur_ms,
  ROUND(PERCENTILE(dur_ms, 0.95), 2) AS p95_dur_ms,
  ROUND(MAX(dur_ms), 2) AS max_dur_ms
FROM webview_slices
GROUP BY phase, process_name, thread_name
ORDER BY max_dur_ms DESC, slice_count DESC
LIMIT 50

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/webview_drawfunctor_jank_chain.skill.yaml
-- Source SHA-256: d05238269f1a158708349ce433365a6f65a5c0446ef30ae94f9138daae0f5cd3
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
-- WEBVIEW_CHROMIUM_SCOPE_CTES_BEGIN
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
                OR s.name GLOB '*DrawGL*'
                OR s.name GLOB '*DrawFn_DrawGL*'
                OR s.name GLOB '*DrawFunctor*'
                OR s.name GLOB '*AwDrawFn*'
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
      s.name GLOB '*DrawGL*' OR s.name GLOB '*DrawFn_DrawGL*' OR
      s.name GLOB '*DrawFunctor*' OR s.name GLOB '*AwDrawFn*' OR
      (
        ci.has_chromium_identity = 1
        AND (t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*')
      )
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
      WHEN ci.has_chromium_identity = 1 AND (t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*') THEN 'chromium_compositor'
      ELSE 'webview_other'
    END AS phase,
    ROUND(s.dur / 1e6, 2) AS dur_ms
  FROM slice s
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
      s.name GLOB '*DrawGL*' OR s.name GLOB '*DrawFn_DrawGL*' OR s.name GLOB '*DrawFunctor*' OR s.name GLOB '*AwDrawFn*' OR
      s.name GLOB '*Blink*' OR s.name GLOB '*Chromium*' OR
      s.name GLOB '*v8*' OR s.name GLOB '*V8*' OR s.name GLOB '*JavaScript*' OR
      (
        ci.has_chromium_identity = 1
        AND (t.name GLOB '*Compositor*' OR s.name GLOB '*Compositor*')
      )
    )
)
-- WEBVIEW_CHROMIUM_SCOPE_CTES_END
SELECT
  phase,
  process_name,
  thread_name,
  COUNT(*) AS slice_count,
  ROUND(AVG(dur_ms), 2) AS avg_dur_ms,
  ROUND(PERCENTILE(dur_ms, 95), 2) AS p95_dur_ms,
  ROUND(MAX(dur_ms), 2) AS max_dur_ms
FROM webview_slices
GROUP BY phase, process_name, thread_name
ORDER BY max_dur_ms DESC, slice_count DESC
LIMIT 50

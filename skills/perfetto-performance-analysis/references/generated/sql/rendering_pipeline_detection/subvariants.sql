-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: 89f9bbab94bb6089b6a022e187c43002cbddfee4b0cb0c728c50f2d79ace3457
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH
      dominant_process AS (
        SELECT
          p.upid,
          p.name as process_name,
          COUNT(*) as render_cnt
        FROM slice s
        JOIN thread_track tt ON s.track_id = tt.id
        JOIN thread t ON tt.utid = t.utid
        JOIN process p ON t.upid = p.upid
        WHERE p.name IS NOT NULL
          AND p.name NOT LIKE 'com.android.systemui%'
          AND p.name NOT LIKE 'system_server%'
          AND p.name NOT LIKE '/system/%'
          AND s.name IS NOT NULL
          AND (
            (t.name = 'RenderThread' AND s.name GLOB 'DrawFrame*')
            OR (t.name = 'main' AND s.name GLOB '*Choreographer#doFrame*')
            OR (s.name GLOB '*lockCanvas*')
            OR (s.name GLOB '*eglSwapBuffers*')
            OR (s.name GLOB '*vkQueuePresentKHR*')
            OR (s.name GLOB '*Swappy*')
            OR (s.name GLOB '*FrameTimeline*')
            OR (s.name GLOB '*updateTexImage*')
          )
        GROUP BY p.upid
        HAVING COUNT(*) > 5
        ORDER BY render_cnt DESC
        LIMIT 1
      ),
      dominant_pkg AS (
        SELECT
          CASE
            WHEN instr(process_name, ':') > 0 THEN substr(process_name, 1, instr(process_name, ':') - 1)
            ELSE process_name
          END as pkg
        FROM dominant_process
      ),
      app_filter_upids AS (
        SELECT p.upid
        FROM process p
        WHERE '${package}' <> '' AND p.name GLOB '${package}*'
        UNION
        SELECT p.upid
        FROM process p
        JOIN dominant_pkg dp
        WHERE '${package}' = ''
          AND dp.pkg IS NOT NULL
          AND p.name GLOB dp.pkg || '*'
          AND p.name NOT LIKE 'com.android.systemui%'
          AND p.name NOT LIKE 'system_server%'
          AND p.name NOT LIKE '/system/%'
      ),
      thread_counts AS (
        SELECT
          t.name as thread_name,
          COUNT(*) as cnt
        FROM thread t
        WHERE t.name IS NOT NULL
          AND t.upid IN (SELECT upid FROM app_filter_upids)
        GROUP BY t.name
      ),
      slice_counts AS (
        SELECT
          s.name as slice_name,
          COUNT(*) as cnt
        FROM slice s
        JOIN thread_track tt ON s.track_id = tt.id
        JOIN thread t ON tt.utid = t.utid
        JOIN process p ON t.upid = p.upid
        WHERE s.name IS NOT NULL
          AND p.upid IN (SELECT upid FROM app_filter_upids)
        GROUP BY s.name
      )
      SELECT
        CASE
          WHEN COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*BLASTBufferQueue*'), 0) > 0 THEN 'BLAST'
          WHEN COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*queueBuffer*'), 0) > 0 THEN 'LEGACY'
          ELSE 'UNKNOWN'
        END as buffer_mode,
        CASE
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts WHERE thread_name IN ('ui', '1.ui')), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*Impeller*' OR slice_name GLOB '*EntityPass*'), 0) > 0
          THEN 'IMPELLER'
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts WHERE thread_name IN ('ui', '1.ui')), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*SkGpu*' OR slice_name GLOB '*SkiaGpu*'), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*EntityPass*'), 0) = 0
          THEN 'SKIA'
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts WHERE thread_name IN ('ui', '1.ui')), 0) > 0
          THEN 'UNKNOWN'
          ELSE 'N/A'
        END as flutter_engine,
        CASE
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts
                         WHERE thread_name = 'VizCompositorThread'
                            OR thread_name GLOB 'VizCompositorThread*'
                            OR thread_name = 'VizCompositor'
                            OR thread_name GLOB 'VizCompositor*'), 0) > 0
          THEN 'SURFACE_CONTROL'
          WHEN COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*DrawGL*' OR slice_name GLOB '*DrawFunctor*'), 0) > 0
          THEN 'GL_FUNCTOR'
          WHEN COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*TBS*' OR slice_name GLOB '*X5*' OR slice_name GLOB '*UCCore*'), 0) > 0
          THEN 'TEXTUREVIEW_CUSTOM'
          WHEN COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*WebView*'), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM slice_counts WHERE slice_name GLOB '*SurfaceView*'), 0) > 0
          THEN 'SURFACEVIEW_WRAPPER'
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts WHERE thread_name GLOB '*Chrome*' OR thread_name GLOB 'CrRendererMain*'), 0) > 0
          THEN 'UNKNOWN'
          ELSE 'N/A'
        END as webview_mode,
        CASE
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts WHERE thread_name GLOB 'UnityMain*'), 0) > 0 THEN 'UNITY'
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts WHERE thread_name GLOB 'GameThread*' OR thread_name GLOB 'RHIThread*'), 0) > 0 THEN 'UNREAL'
          WHEN COALESCE((SELECT SUM(cnt) FROM thread_counts WHERE thread_name GLOB 'GodotMain*'), 0) > 0 THEN 'GODOT'
          ELSE 'N/A'
        END as game_engine

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: 89f9bbab94bb6089b6a022e187c43002cbddfee4b0cb0c728c50f2d79ace3457
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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
            OR (s.name GLOB '*unlockCanvasAndPost*')
            OR (s.name GLOB '*eglSwapBuffers*')
            OR (s.name GLOB '*vkQueuePresentKHR*')
            OR (s.name GLOB '*Swappy*')
            OR (s.name GLOB '*FramePacing*')
            OR (s.name GLOB '*FrameTimeline*')
            OR (s.name GLOB '*updateTexImage*')
            OR (s.name GLOB '*Rasterizer::DrawToSurfaces*')
            OR (s.name GLOB '*Engine::BeginFrame*')
            OR (s.name GLOB '*EntityPass*')
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
      marker_slices AS (
        SELECT
          p.upid,
          p.name as process_name,
          t.tid,
          t.name as thread_name
        FROM slice s
        JOIN thread_track tt ON s.track_id = tt.id
        JOIN thread t ON tt.utid = t.utid
        JOIN process p ON t.upid = p.upid
        WHERE p.upid IN (SELECT upid FROM app_filter_upids)
          AND p.name IS NOT NULL
          AND s.name IS NOT NULL
          AND (
            (t.name = 'RenderThread' AND s.name GLOB 'DrawFrame*')
            OR (s.name GLOB '*eglSwapBuffers*')
            OR (s.name GLOB '*vkQueuePresentKHR*')
            OR (s.name GLOB '*Swappy*')
            OR (s.name GLOB '*FramePacing*')
            OR (s.name GLOB '*updateTexImage*')
            OR (s.name GLOB '*Rasterizer::DrawToSurfaces*')
            OR (s.name GLOB '*Engine::BeginFrame*')
            OR (s.name GLOB '*EntityPass*')
            OR (s.name GLOB '*lockCanvas*')
            OR (s.name GLOB '*unlockCanvasAndPost*')
          )
      )
      SELECT
        upid,
        process_name,
        COUNT(*) as frame_count,
        MAX(CASE WHEN thread_name = 'RenderThread' THEN tid ELSE NULL END) as render_thread_tid
      FROM marker_slices
      GROUP BY upid
      HAVING frame_count > 5
      ORDER BY frame_count DESC
      LIMIT 10

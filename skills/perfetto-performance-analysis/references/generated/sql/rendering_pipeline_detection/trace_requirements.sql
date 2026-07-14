-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: 89f9bbab94bb6089b6a022e187c43002cbddfee4b0cb0c728c50f2d79ace3457
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

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
      )
      SELECT
        CASE
          WHEN NOT EXISTS (
            SELECT 1
            FROM slice s
            JOIN thread_track tt ON s.track_id = tt.id
            JOIN thread t ON tt.utid = t.utid
            JOIN process p ON t.upid = p.upid
            WHERE p.upid IN (SELECT upid FROM app_filter_upids)
              AND t.name = 'RenderThread'
              AND s.name GLOB 'DrawFrame*'
            LIMIT 1
          )
          THEN 'gfx: RenderThread/DrawFrame slices missing (enable atrace: gfx)'
          ELSE NULL
        END as hint_gfx,
        CASE
          WHEN NOT EXISTS (
            SELECT 1
            FROM slice s
            JOIN thread_track tt ON s.track_id = tt.id
            JOIN thread t ON tt.utid = t.utid
            JOIN process p ON t.upid = p.upid
            WHERE p.upid IN (SELECT upid FROM app_filter_upids)
              AND s.name GLOB '*Choreographer#doFrame*'
            LIMIT 1
          )
          THEN 'input: Choreographer#doFrame missing (enable atrace: input/view)'
          ELSE NULL
        END as hint_input,
        CASE
          WHEN NOT EXISTS (
            SELECT 1
            FROM slice s
            JOIN thread_track tt ON s.track_id = tt.id
            JOIN thread t ON tt.utid = t.utid
            JOIN process p ON t.upid = p.upid
            WHERE p.upid IN (SELECT upid FROM app_filter_upids)
              AND (
                s.name GLOB '*BLASTBufferQueue*'
                OR s.name GLOB '*applyTransaction*'
                OR s.name GLOB '*queueBuffer*'
                OR s.name GLOB '*dequeueBuffer*'
              )
            LIMIT 1
          )
          THEN 'BufferQueue/Transaction slices missing (enable atrace: gfx/sf)'
          ELSE NULL
        END as hint_buffer,
        CASE
          WHEN NOT EXISTS (SELECT 1 FROM process p WHERE p.name = 'surfaceflinger' LIMIT 1)
          THEN 'SurfaceFlinger process missing (need system tracing / root on some devices)'
          ELSE NULL
        END as hint_sf,
        CASE
          WHEN NOT EXISTS (SELECT 1 FROM slice s WHERE s.name GLOB '*FrameTimeline*' LIMIT 1)
          THEN 'FrameTimeline missing (enable SurfaceFlinger FrameTimeline / Android 12+)'
          ELSE NULL
        END as hint_timeline

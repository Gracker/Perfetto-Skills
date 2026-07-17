-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: 89f9bbab94bb6089b6a022e187c43002cbddfee4b0cb0c728c50f2d79ace3457
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
            OR (s.name GLOB '*Choreographer#doFrame*')
            OR (s.name GLOB '*eglSwapBuffers*')
            OR (s.name GLOB '*vkQueuePresentKHR*')
            OR (s.name GLOB '*FrameTimeline*')
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
      app_layers AS (
        -- FrameTimeline 提供 layer_name 维度（Android 12+）
        SELECT DISTINCT layer_name
        FROM android_frames_layers
        WHERE layer_name IS NOT NULL
          AND (
            ('${package}' <> '' AND layer_name GLOB '*' || '${package}' || '*')
            OR ('${package}' = '' AND layer_name GLOB '*' || (SELECT pkg FROM dominant_pkg) || '*')
          )
      )
      SELECT
        COALESCE((SELECT COUNT(*) FROM app_layers), 0) as app_layer_count,
        COALESCE((SELECT GROUP_CONCAT(layer_name, '; ') FROM app_layers), '') as app_layer_names,
        CASE
          WHEN (SELECT COUNT(*) FROM app_layers WHERE layer_name GLOB '*SurfaceView*' OR layer_name GLOB 'SurfaceView*') > 0 THEN 1
          ELSE 0
        END as has_surfaceview_layer,
        CASE
          WHEN (SELECT COUNT(*) FROM app_layers WHERE layer_name GLOB '*video*' OR layer_name GLOB '*Video*' OR layer_name GLOB '*MediaCodec*') > 0 THEN 1
          ELSE 0
        END as has_video_layer,
        CASE
          WHEN (SELECT COUNT(*) FROM app_layers WHERE layer_name GLOB '*io.flutter*' OR layer_name GLOB '*Flutter*') > 0 THEN 1
          ELSE 0
        END as has_flutter_layer,
        CASE
          WHEN (SELECT COUNT(*) FROM app_layers WHERE layer_name GLOB '*Camera*' OR layer_name GLOB '*camera*') > 0 THEN 1
          ELSE 0
        END as has_camera_layer

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
      app_slices AS (
        SELECT s.name as slice_name, COUNT(*) as cnt
        FROM slice s
        JOIN thread_track tt ON s.track_id = tt.id
        JOIN thread t ON tt.utid = t.utid
        JOIN process p ON t.upid = p.upid
        WHERE s.name IS NOT NULL
          AND p.upid IN (SELECT upid FROM app_filter_upids)
        GROUP BY s.name
      )
      SELECT
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*BLASTBufferQueue*'), 0) as blast_bq_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*applyTransaction*'), 0) as apply_transaction_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*queueBuffer*'), 0) as queue_buffer_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*updateTexImage*'), 0) as update_tex_image_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*lockCanvas*'), 0) as lock_canvas_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*unlockCanvasAndPost*'), 0) as unlock_canvas_post_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*ASurfaceTransaction*'), 0) as asurface_transaction_count,
        CASE
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*BLASTBufferQueue*'), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*applyTransaction*'), 0) > 0
            THEN 'BBQ_TRANSACTION_INPROC'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*ASurfaceTransaction*'), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*BLASTBufferQueue*'), 0) = 0
            THEN 'SURFACECONTROL_TRANSACTION_DIRECT'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*updateTexImage*'), 0) > 0
            THEN 'HOST_RESAMPLE'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*lockCanvas*' OR slice_name GLOB '*unlockCanvasAndPost*'), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*BLASTBufferQueue*'), 0) = 0
            THEN 'ACQUIRE_FENCE_NONE_INPROC'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*queueBuffer*'), 0) > 0
               AND COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*BLASTBufferQueue*'), 0) = 0
               AND COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*applyTransaction*'), 0) = 0
            THEN 'BUFFERQUEUE_INPROC'
          ELSE 'UNKNOWN'
        END as bufferqueue_path

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: 89f9bbab94bb6089b6a022e187c43002cbddfee4b0cb0c728c50f2d79ace3457
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

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
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*Swappy*'), 0) as swappy_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*SwappyVk_*'), 0) as swappy_vk_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*AChoreographer*'), 0) as achoreographer_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*setFrameRate*'), 0) as set_frame_rate_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*setFrameRateCategory*'), 0) as set_frame_rate_category_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*PlayerLoop*' OR slice_name GLOB '*FEngineLoop*' OR slice_name GLOB '*MainLoop*'), 0) as engine_main_loop_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*processCaptureRequest*' OR slice_name GLOB '*processCaptureResult*'), 0) as camera_capture_count,
        COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*releaseOutputBuffer*' OR slice_name GLOB '*MediaCodec*'), 0) as mediacodec_pacing_count,
        CASE
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*Swappy*' OR slice_name GLOB '*SwappyVk_*'), 0) > 0 THEN 'swappy_pacing'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*AChoreographer*'), 0) > 0 THEN 'achoreographer'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*PlayerLoop*' OR slice_name GLOB '*FEngineLoop*' OR slice_name GLOB '*MainLoop*'), 0) > 0 THEN 'engine_main_loop'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*processCaptureRequest*'), 0) > 0 THEN 'camera_request_activity'
          WHEN COALESCE((SELECT SUM(cnt) FROM app_slices WHERE slice_name GLOB '*releaseOutputBuffer*'), 0) > 0 THEN 'video_codec_pacing'
          ELSE 'vsync_app_only'
        END as primary_rhythm_source

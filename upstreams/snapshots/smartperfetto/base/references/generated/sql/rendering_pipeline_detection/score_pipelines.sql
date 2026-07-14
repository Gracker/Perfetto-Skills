-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: 89f9bbab94bb6089b6a022e187c43002cbddfee4b0cb0c728c50f2d79ace3457
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH
      -- Identify a dominant app (when package is not provided) by looking for rendering-related slices,
      -- then include *all* processes that share the same package prefix. This reduces false positives
      -- from multi-app traces while still supporting multi-process apps (e.g. WebView renderers).
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
          SUM(CASE WHEN t.upid IN (SELECT upid FROM app_filter_upids) THEN 1 ELSE 0 END) as app_cnt,
          COUNT(*) as global_cnt
        FROM thread t
        WHERE t.name IS NOT NULL
        GROUP BY t.name
      ),
      slice_counts AS (
        SELECT
          s.name as slice_name,
          SUM(CASE WHEN p.upid IN (SELECT upid FROM app_filter_upids) THEN 1 ELSE 0 END) as app_cnt,
          COUNT(*) as global_cnt
        FROM slice s
        JOIN thread_track tt ON s.track_id = tt.id
        JOIN thread t ON tt.utid = t.utid
        JOIN process p ON t.upid = p.upid
        WHERE s.name IS NOT NULL
        GROUP BY s.name
      ),
      pipeline_list(pipeline_id) AS (
        VALUES
        ('ANDROID_PIP_FREEFORM'),
        ('ANDROID_VIEW_MIXED'),
        ('ANDROID_VIEW_MULTI_WINDOW'),
        ('ANDROID_VIEW_SOFTWARE'),
        ('ANDROID_VIEW_STANDARD_BLAST'),
        ('ANDROID_VIEW_STANDARD_LEGACY'),
        ('ANGLE_GLES_VULKAN'),
        ('CAMERA_PIPELINE'),
        ('CHROME_BROWSER_VIZ'),
        ('COMPOSE_STANDARD'),
        ('FLUTTER_SURFACEVIEW_IMPELLER'),
        ('FLUTTER_SURFACEVIEW_SKIA'),
        ('FLUTTER_TEXTUREVIEW'),
        ('GAME_ENGINE'),
        ('HARDWARE_BUFFER_RENDERER'),
        ('IMAGEREADER_PIPELINE'),
        ('OPENGL_ES'),
        ('RN_NEW_ARCH_HWUI'),
        ('RN_OLD_ARCH_HWUI'),
        ('RN_SKIA_RENDERER'),
        ('SOFTWARE_COMPOSITING'),
        ('SURFACE_CONTROL_API'),
        ('SURFACEVIEW_BLAST'),
        ('TEXTUREVIEW_STANDARD'),
        ('VARIABLE_REFRESH_RATE'),
        ('VIDEO_OVERLAY_HWC'),
        ('VULKAN_NATIVE'),
        ('WEBVIEW_GL_FUNCTOR'),
        ('WEBVIEW_SURFACE_CONTROL'),
        ('WEBVIEW_SURFACEVIEW_WRAPPER'),
        ('WEBVIEW_TEXTUREVIEW_CUSTOM')
      ),
      signal_defs(signal_id, pipeline_id, signal_type, signal_name, weight, min_count, source, op, pattern, scope) AS (
        VALUES
        (0, 'ANDROID_PIP_FREEFORM', 's', 'has_enter_pip_api', 50, 1, 's', 'glob', '*enterPictureInPictureMode*', 'g'),
        (1, 'ANDROID_PIP_FREEFORM', 's', 'has_pip_marker', 50, 1, 's', 'glob', '*PictureInPicture*', 'g'),
        (2, 'ANDROID_PIP_FREEFORM', 's', 'has_wms_resize_task', 50, 1, 's', 'glob', '*WMS.resizeTask*', 'g'),
        (3, 'ANDROID_VIEW_MIXED', 'r', 'thread:RenderThread', 0, 1, 't', 'eq', 'RenderThread', 'a'),
        (4, 'ANDROID_VIEW_MIXED', 'r', 'thread:main', 0, 1, 't', 'eq', 'main', 'a'),
        (5, 'ANDROID_VIEW_MIXED', 's', 'has_surfaceview', 50, 1, 's', 'glob', '*SurfaceView*', 'a'),
        (6, 'ANDROID_VIEW_MIXED', 's', 'has_draw_frame', 20, 1, 's', 'glob', 'DrawFrame*', 'a'),
        (7, 'ANDROID_VIEW_MIXED', 's', 'has_mediacodec_thread', 12, 1, 't', 'glob', '*MediaCodec*', 'a'),
        (8, 'ANDROID_VIEW_MIXED', 's', 'has_decoder_thread', 8, 1, 't', 'glob', '*Decoder*', 'a'),
        (9, 'ANDROID_VIEW_MIXED', 's', 'has_update_tex_image_active', 8, 2, 's', 'glob', '*updateTexImage*', 'a'),
        (10, 'ANDROID_VIEW_MIXED', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (11, 'ANDROID_VIEW_MIXED', 'e', 'thread:CrRendererMain', 0, 1, 't', 'eq', 'CrRendererMain', 'a'),
        (12, 'ANDROID_VIEW_MIXED', 'e', 'thread:UnityMain', 0, 1, 't', 'eq', 'UnityMain', 'a'),
        (13, 'ANDROID_VIEW_MULTI_WINDOW', 'r', 'thread:RenderThread', 0, 1, 't', 'eq', 'RenderThread', 'a'),
        (14, 'ANDROID_VIEW_MULTI_WINDOW', 'r', 'thread:main', 0, 1, 't', 'eq', 'main', 'a'),
        (15, 'ANDROID_VIEW_MULTI_WINDOW', 's', 'has_dialog', 20, 1, 's', 'glob', '*Dialog*', 'a'),
        (16, 'ANDROID_VIEW_MULTI_WINDOW', 's', 'has_popup_window', 20, 1, 's', 'glob', '*PopupWindow*', 'a'),
        (17, 'ANDROID_VIEW_MULTI_WINDOW', 's', 'has_draw_frame', 20, 1, 's', 'glob', 'DrawFrame*', 'a'),
        (18, 'ANDROID_VIEW_MULTI_WINDOW', 's', 'has_perform_traversals_multi', 12, 2, 's', 'glob', '*performTraversals*', 'a'),
        (19, 'ANDROID_VIEW_SOFTWARE', 'r', 'thread:main', 0, 1, 't', 'eq', 'main', 'a'),
        (20, 'ANDROID_VIEW_SOFTWARE', 's', 'has_lock_canvas', 55, 1, 's', 'glob', '*lockCanvas*', 'a'),
        (21, 'ANDROID_VIEW_SOFTWARE', 's', 'has_unlock_canvas_post', 55, 1, 's', 'glob', '*unlockCanvasAndPost*', 'a'),
        (22, 'ANDROID_VIEW_SOFTWARE', 'e', 'thread:RenderThread', 0, 1, 't', 'eq', 'RenderThread', 'a'),
        (23, 'ANDROID_VIEW_SOFTWARE', 'e', 'slice_pattern:DrawFrame*', 0, 1, 's', 'glob', 'DrawFrame*', 'a'),
        (24, 'ANDROID_VIEW_STANDARD_BLAST', 'r', 'thread:RenderThread', 0, 1, 't', 'eq', 'RenderThread', 'a'),
        (25, 'ANDROID_VIEW_STANDARD_BLAST', 'r', 'thread:main', 0, 1, 't', 'eq', 'main', 'a'),
        (26, 'ANDROID_VIEW_STANDARD_BLAST', 's', 'has_draw_frame', 25, 1, 's', 'glob', 'DrawFrame*', 'a'),
        (27, 'ANDROID_VIEW_STANDARD_BLAST', 's', 'has_choreographer', 20, 1, 's', 'glob', '*Choreographer#doFrame*', 'a'),
        (28, 'ANDROID_VIEW_STANDARD_BLAST', 's', 'has_sync_frame', 15, 1, 's', 'glob', '*syncFrameState*', 'a'),
        (29, 'ANDROID_VIEW_STANDARD_BLAST', 's', 'has_queue_buffer', 12, 1, 's', 'glob', '*queueBuffer*', 'a'),
        (30, 'ANDROID_VIEW_STANDARD_BLAST', 's', 'has_blast_buffer_queue_hint', 10, 1, 's', 'glob', '*BLASTBufferQueue*', 'a'),
        (31, 'ANDROID_VIEW_STANDARD_BLAST', 's', 'has_set_transaction_state', 10, 1, 's', 'glob', '*setTransactionState*', 'a'),
        (32, 'ANDROID_VIEW_STANDARD_BLAST', 's', 'has_apply_transaction', 12, 1, 's', 'glob', '*applyTransaction*', 'a'),
        (33, 'ANDROID_VIEW_STANDARD_BLAST', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (34, 'ANDROID_VIEW_STANDARD_BLAST', 'e', 'thread:1.raster', 0, 1, 't', 'eq', '1.raster', 'a'),
        (35, 'ANDROID_VIEW_STANDARD_BLAST', 'e', 'thread:CrRendererMain', 0, 1, 't', 'eq', 'CrRendererMain', 'a'),
        (36, 'ANDROID_VIEW_STANDARD_BLAST', 'e', 'thread:UnityMain', 0, 1, 't', 'eq', 'UnityMain', 'a'),
        (37, 'ANDROID_VIEW_STANDARD_BLAST', 'e', 'thread:UnityGfx', 0, 1, 't', 'eq', 'UnityGfx', 'a'),
        (38, 'ANDROID_VIEW_STANDARD_LEGACY', 'r', 'thread:RenderThread', 0, 1, 't', 'eq', 'RenderThread', 'a'),
        (39, 'ANDROID_VIEW_STANDARD_LEGACY', 'r', 'thread:main', 0, 1, 't', 'eq', 'main', 'a'),
        (40, 'ANDROID_VIEW_STANDARD_LEGACY', 's', 'has_queue_buffer', 30, 1, 's', 'glob', '*queueBuffer*', 'a'),
        (41, 'ANDROID_VIEW_STANDARD_LEGACY', 's', 'has_dequeue_buffer', 20, 1, 's', 'glob', '*dequeueBuffer*', 'a'),
        (42, 'ANDROID_VIEW_STANDARD_LEGACY', 's', 'has_draw_frame', 25, 1, 's', 'glob', 'DrawFrame*', 'a'),
        (43, 'ANDROID_VIEW_STANDARD_LEGACY', 'e', 'slice_pattern:*BLASTBufferQueue*', 0, 1, 's', 'glob', '*BLASTBufferQueue*', 'a'),
        (44, 'ANDROID_VIEW_STANDARD_LEGACY', 'e', 'slice_pattern:*applyTransaction*', 0, 1, 's', 'glob', '*applyTransaction*', 'a'),
        (45, 'ANDROID_VIEW_STANDARD_LEGACY', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (46, 'ANDROID_VIEW_STANDARD_LEGACY', 'e', 'thread:CrRendererMain', 0, 1, 't', 'eq', 'CrRendererMain', 'a'),
        (47, 'ANDROID_VIEW_STANDARD_LEGACY', 'e', 'thread:UnityMain', 0, 1, 't', 'eq', 'UnityMain', 'a'),
        (48, 'ANDROID_VIEW_STANDARD_LEGACY', 'e', 'thread:UnityGfx', 0, 1, 't', 'eq', 'UnityGfx', 'a'),
        (49, 'ANGLE_GLES_VULKAN', 'r', 'slice_pattern:*vkQueuePresentKHR*', 0, 1, 's', 'glob', '*vkQueuePresentKHR*', 'a'),
        (50, 'ANGLE_GLES_VULKAN', 's', 'has_angle', 80, 1, 's', 'glob', '*ANGLE*', 'a'),
        (51, 'CAMERA_PIPELINE', 's', 'has_camera_thread', 30, 1, 't', 'glob', '*Camera*', 'a'),
        (52, 'CAMERA_PIPELINE', 's', 'has_cam_abbrev_thread', 10, 1, 't', 'glob', '*Cam*', 'a'),
        (53, 'CAMERA_PIPELINE', 's', 'has_camera_slice', 30, 1, 's', 'glob', '*Camera*', 'a'),
        (54, 'CAMERA_PIPELINE', 's', 'has_capture_session', 30, 1, 's', 'glob', '*CaptureSession*', 'a'),
        (55, 'CHROME_BROWSER_VIZ', 'r', 'thread:VizCompositorThread', 0, 1, 't', 'eq', 'VizCompositorThread', 'a'),
        (56, 'CHROME_BROWSER_VIZ', 'r', 'thread_pattern:CrBrowserMain*', 0, 1, 't', 'glob', 'CrBrowserMain*', 'a'),
        (57, 'CHROME_BROWSER_VIZ', 's', 'has_viz_compositor_thread', 40, 1, 't', 'glob', 'VizCompositorThread', 'a'),
        (58, 'CHROME_BROWSER_VIZ', 's', 'has_cr_renderer_main', 25, 1, 't', 'glob', 'CrRendererMain*', 'a'),
        (59, 'CHROME_BROWSER_VIZ', 's', 'has_gpu_main', 20, 1, 't', 'glob', 'CrGpuMain*', 'a'),
        (60, 'CHROME_BROWSER_VIZ', 's', 'has_display_scheduler', 15, 1, 's', 'glob', '*DisplayScheduler*', 'a'),
        (61, 'CHROME_BROWSER_VIZ', 's', 'has_begin_frame', 10, 1, 's', 'glob', '*BeginFrame*', 'a'),
        (62, 'CHROME_BROWSER_VIZ', 's', 'has_chromium_compositor', 10, 1, 's', 'glob', '*Chromium.Compositor*', 'a'),
        (63, 'CHROME_BROWSER_VIZ', 'e', 'slice_pattern:*WebViewChromium*', 0, 1, 's', 'glob', '*WebViewChromium*', 'a'),
        (64, 'CHROME_BROWSER_VIZ', 'e', 'slice_pattern:*WebView*loadUrl*', 0, 1, 's', 'glob', '*WebView*loadUrl*', 'a'),
        (65, 'CHROME_BROWSER_VIZ', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (66, 'CHROME_BROWSER_VIZ', 'e', 'thread:1.raster', 0, 1, 't', 'eq', '1.raster', 'a'),
        (67, 'CHROME_BROWSER_VIZ', 'e', 'thread:UnityMain', 0, 1, 't', 'eq', 'UnityMain', 'a'),
        (68, 'CHROME_BROWSER_VIZ', 'e', 'thread:UnityGfx', 0, 1, 't', 'eq', 'UnityGfx', 'a'),
        (69, 'COMPOSE_STANDARD', 'r', 'thread:RenderThread', 0, 1, 't', 'eq', 'RenderThread', 'a'),
        (70, 'COMPOSE_STANDARD', 'r', 'thread:main', 0, 1, 't', 'eq', 'main', 'a'),
        (71, 'COMPOSE_STANDARD', 's', 'has_recomposition', 80, 1, 's', 'glob', 'Recompos*', 'a'),
        (72, 'COMPOSE_STANDARD', 's', 'has_compose_prefix', 40, 1, 's', 'glob', 'Compose:*', 'a'),
        (73, 'COMPOSE_STANDARD', 's', 'has_composition_local', 30, 1, 's', 'glob', '*CompositionLocal*', 'a'),
        (74, 'COMPOSE_STANDARD', 's', 'has_measure_layout', 10, 1, 's', 'glob', '*measure*', 'a'),
        (75, 'COMPOSE_STANDARD', 's', 'has_draw_frame', 15, 1, 's', 'glob', 'DrawFrame*', 'a'),
        (76, 'COMPOSE_STANDARD', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (77, 'COMPOSE_STANDARD', 'e', 'thread:CrRendererMain', 0, 1, 't', 'eq', 'CrRendererMain', 'a'),
        (78, 'FLUTTER_SURFACEVIEW_IMPELLER', 's', 'has_impeller', 45, 1, 's', 'glob', '*Impeller*', 'a'),
        (79, 'FLUTTER_SURFACEVIEW_IMPELLER', 's', 'has_entity_pass_hint', 20, 1, 's', 'glob', '*EntityPass*', 'a'),
        (80, 'FLUTTER_SURFACEVIEW_IMPELLER', 's', 'has_flutter_raster', 12, 1, 't', 'glob', '*raster*', 'a'),
        (81, 'FLUTTER_SURFACEVIEW_IMPELLER', 's', 'has_flutter_ui_hint', 8, 1, 't', 'glob', '*ui*', 'a'),
        (82, 'FLUTTER_SURFACEVIEW_IMPELLER', 's', 'has_dart_worker', 18, 1, 't', 'glob', 'DartWorker*', 'a'),
        (83, 'FLUTTER_SURFACEVIEW_IMPELLER', 's', 'has_flutter_jit', 12, 1, 's', 'glob', '*io.flutter*', 'a'),
        (84, 'FLUTTER_SURFACEVIEW_IMPELLER', 'e', 'slice_pattern:*SkGpu*', 0, 1, 's', 'glob', '*SkGpu*', 'a'),
        (85, 'FLUTTER_SURFACEVIEW_IMPELLER', 'e', 'slice_pattern:*SkiaGpu*', 0, 1, 's', 'glob', '*SkiaGpu*', 'a'),
        (86, 'FLUTTER_SURFACEVIEW_SKIA', 's', 'has_skgpu', 35, 1, 's', 'glob', '*SkGpu*', 'a'),
        (87, 'FLUTTER_SURFACEVIEW_SKIA', 's', 'has_skiagpu', 30, 1, 's', 'glob', '*SkiaGpu*', 'a'),
        (88, 'FLUTTER_SURFACEVIEW_SKIA', 's', 'has_flutter_raster', 10, 1, 't', 'glob', '*raster*', 'a'),
        (89, 'FLUTTER_SURFACEVIEW_SKIA', 's', 'has_flutter_ui_hint', 8, 1, 't', 'glob', '*ui*', 'a'),
        (90, 'FLUTTER_SURFACEVIEW_SKIA', 's', 'has_dart_worker', 18, 1, 't', 'glob', 'DartWorker*', 'a'),
        (91, 'FLUTTER_SURFACEVIEW_SKIA', 's', 'has_flutter_jit', 12, 1, 's', 'glob', '*io.flutter*', 'a'),
        (92, 'FLUTTER_SURFACEVIEW_SKIA', 'e', 'slice_pattern:*EntityPass*', 0, 1, 's', 'glob', '*EntityPass*', 'a'),
        (93, 'FLUTTER_TEXTUREVIEW', 's', 'has_surface_texture', 30, 1, 's', 'glob', '*SurfaceTexture*', 'a'),
        (94, 'FLUTTER_TEXTUREVIEW', 's', 'has_update_tex_image', 15, 1, 's', 'glob', '*updateTexImage*', 'a'),
        (95, 'FLUTTER_TEXTUREVIEW', 's', 'has_host_render_thread', 12, 1, 't', 'glob', 'RenderThread*', 'a'),
        (96, 'FLUTTER_TEXTUREVIEW', 's', 'has_flutter_raster', 10, 1, 't', 'glob', '*raster*', 'a'),
        (97, 'GAME_ENGINE', 's', 'has_unity_main', 85, 1, 't', 'glob', 'UnityMain*', 'a'),
        (98, 'GAME_ENGINE', 's', 'has_unity_gfx', 85, 1, 't', 'glob', 'UnityGfx*', 'a'),
        (99, 'GAME_ENGINE', 's', 'has_unreal_game', 85, 1, 't', 'glob', 'GameThread*', 'a'),
        (100, 'GAME_ENGINE', 's', 'has_unreal_rhi', 85, 1, 't', 'glob', 'RHIThread*', 'a'),
        (101, 'GAME_ENGINE', 's', 'has_godot', 80, 1, 't', 'glob', 'GodotMain*', 'a'),
        (102, 'GAME_ENGINE', 's', 'has_cocos_lower', 35, 1, 't', 'glob', '*cocos*', 'a'),
        (103, 'GAME_ENGINE', 's', 'has_cocos_upper', 40, 1, 't', 'glob', '*Cocos*', 'a'),
        (104, 'GAME_ENGINE', 's', 'has_unity_slice', 45, 1, 's', 'glob', '*Unity*', 'a'),
        (105, 'GAME_ENGINE', 's', 'has_player_loop', 30, 1, 's', 'glob', '*PlayerLoop*', 'a'),
        (106, 'GAME_ENGINE', 's', 'has_unreal_slice', 75, 1, 's', 'glob', '*Unreal*', 'a'),
        (107, 'GAME_ENGINE', 's', 'has_swappy', 10, 1, 's', 'glob', '*Swappy*', 'a'),
        (108, 'GAME_ENGINE', 's', 'has_frame_pacing', 5, 1, 's', 'glob', '*FramePacing*', 'a'),
        (109, 'HARDWARE_BUFFER_RENDERER', 's', 'has_hardware_buffer_renderer', 55, 1, 's', 'glob', '*HardwareBufferRenderer*', 'a'),
        (110, 'HARDWARE_BUFFER_RENDERER', 's', 'has_ahardware_buffer_renderer', 20, 1, 's', 'glob', '*AHardwareBufferRenderer*', 'a'),
        (111, 'HARDWARE_BUFFER_RENDERER', 's', 'has_render_node', 15, 1, 's', 'glob', '*RenderNode*', 'a'),
        (112, 'HARDWARE_BUFFER_RENDERER', 's', 'has_recording_canvas', 10, 1, 's', 'glob', '*RecordingCanvas*', 'a'),
        (113, 'IMAGEREADER_PIPELINE', 'r', 'slice_pattern:*ImageReader*', 0, 1, 's', 'glob', '*ImageReader*', 'a'),
        (114, 'IMAGEREADER_PIPELINE', 's', 'has_acquire_next_image', 30, 1, 's', 'glob', '*acquireNextImage*', 'a'),
        (115, 'IMAGEREADER_PIPELINE', 's', 'has_ndk_imagereader', 25, 1, 's', 'glob', '*AImageReader*', 'a'),
        (116, 'IMAGEREADER_PIPELINE', 's', 'has_hardware_buffer', 20, 1, 's', 'glob', '*HardwareBuffer*', 'a'),
        (117, 'IMAGEREADER_PIPELINE', 's', 'has_on_image_available', 20, 1, 's', 'glob', '*onImageAvailable*', 'a'),
        (118, 'IMAGEREADER_PIPELINE', 's', 'has_queue_buffer', 15, 1, 's', 'glob', '*queueBuffer*', 'a'),
        (119, 'IMAGEREADER_PIPELINE', 's', 'has_media_codec', 10, 1, 's', 'glob', '*MediaCodec*', 'a'),
        (120, 'OPENGL_ES', 'r', 'thread_pattern:*GLThread*', 0, 1, 't', 'glob', '*GLThread*', 'a'),
        (121, 'OPENGL_ES', 's', 'has_egl_swap', 50, 1, 's', 'glob', '*eglSwapBuffers*', 'a'),
        (122, 'OPENGL_ES', 's', 'has_gl_draw', 20, 1, 's', 'glob', '*glDraw*', 'a'),
        (123, 'OPENGL_ES', 's', 'has_gl_thread', 15, 1, 't', 'glob', '*GLThread*', 'a'),
        (124, 'OPENGL_ES', 'e', 'slice_pattern:*vkQueuePresentKHR*', 0, 1, 's', 'glob', '*vkQueuePresentKHR*', 'a'),
        (125, 'OPENGL_ES', 'e', 'slice_pattern:*ANGLE*', 0, 1, 's', 'glob', '*ANGLE*', 'a'),
        (126, 'OPENGL_ES', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (127, 'OPENGL_ES', 'e', 'thread:CrRendererMain', 0, 1, 't', 'eq', 'CrRendererMain', 'a'),
        (128, 'OPENGL_ES', 'e', 'thread:UnityMain', 0, 1, 't', 'eq', 'UnityMain', 'a'),
        (129, 'RN_NEW_ARCH_HWUI', 'r', 'slice_pattern:*FabricUIManager*', 0, 1, 's', 'glob', '*FabricUIManager*', 'a'),
        (130, 'RN_NEW_ARCH_HWUI', 's', 'has_fabric_uimanager', 50, 1, 's', 'glob', '*FabricUIManager*', 'a'),
        (131, 'RN_NEW_ARCH_HWUI', 's', 'has_fabric_commit', 25, 1, 's', 'glob', '*FabricCommit*', 'a'),
        (132, 'RN_NEW_ARCH_HWUI', 's', 'has_fabric_mount', 25, 1, 's', 'glob', '*FabricMount*', 'a'),
        (133, 'RN_NEW_ARCH_HWUI', 's', 'has_jsi_call', 15, 1, 's', 'glob', '*JSI*', 'a'),
        (134, 'RN_NEW_ARCH_HWUI', 's', 'has_turbomodule', 15, 1, 's', 'glob', '*TurboModule*', 'a'),
        (135, 'RN_NEW_ARCH_HWUI', 's', 'has_mqt_js', 20, 1, 't', 'glob', 'mqt_js*', 'a'),
        (136, 'RN_NEW_ARCH_HWUI', 'e', 'thread_pattern:mqt_shadow*', 0, 1, 't', 'glob', 'mqt_shadow*', 'a'),
        (137, 'RN_OLD_ARCH_HWUI', 'r', 'thread_pattern:mqt_*', 0, 1, 't', 'glob', 'mqt_*', 'a'),
        (138, 'RN_OLD_ARCH_HWUI', 's', 'has_mqt_js', 50, 1, 't', 'glob', 'mqt_js*', 'a'),
        (139, 'RN_OLD_ARCH_HWUI', 's', 'has_mqt_native_modules', 30, 1, 't', 'glob', 'mqt_native_modules*', 'a'),
        (140, 'RN_OLD_ARCH_HWUI', 's', 'has_mqt_shadow', 25, 1, 't', 'glob', 'mqt_shadow*', 'a'),
        (141, 'RN_OLD_ARCH_HWUI', 's', 'has_yoga_layout', 15, 1, 's', 'glob', '*Yoga*', 'a'),
        (142, 'RN_OLD_ARCH_HWUI', 's', 'has_native_to_js', 10, 1, 's', 'glob', '*NativeToJsBridge*', 'a'),
        (143, 'RN_OLD_ARCH_HWUI', 's', 'has_js_to_native', 10, 1, 's', 'glob', '*JsToNativeBridge*', 'a'),
        (144, 'RN_OLD_ARCH_HWUI', 's', 'has_uimanager', 12, 1, 's', 'glob', '*UIManager*dispatchViewUpdates*', 'a'),
        (145, 'RN_OLD_ARCH_HWUI', 'e', 'slice_pattern:*FabricUIManager*', 0, 1, 's', 'glob', '*FabricUIManager*', 'a'),
        (146, 'RN_SKIA_RENDERER', 's', 'has_mqt_js', 30, 1, 't', 'glob', 'mqt_js*', 'a'),
        (147, 'RN_SKIA_RENDERER', 's', 'has_skia_renderer', 25, 1, 's', 'glob', '*SkiaRenderer*', 'a'),
        (148, 'RN_SKIA_RENDERER', 's', 'has_skia_picture', 20, 1, 's', 'glob', '*SkiaPicture*', 'a'),
        (149, 'RN_SKIA_RENDERER', 's', 'has_react_native_skia', 25, 1, 's', 'glob', '*react-native-skia*', 'a'),
        (150, 'RN_SKIA_RENDERER', 's', 'has_skia_paint', 10, 1, 's', 'glob', '*SkPaint*', 'a'),
        (151, 'RN_SKIA_RENDERER', 's', 'has_skia_canvas', 10, 1, 's', 'glob', '*SkCanvas*', 'a'),
        (152, 'RN_SKIA_RENDERER', 'e', 'slice_pattern:*FabricUIManager*', 0, 1, 's', 'glob', '*FabricUIManager*', 'a'),
        (153, 'RN_SKIA_RENDERER', 'e', 'thread_pattern:mqt_shadow*', 0, 1, 't', 'glob', 'mqt_shadow*', 'a'),
        (154, 'RN_SKIA_RENDERER', 'e', 'slice_pattern:*EntityPass*', 0, 1, 's', 'glob', '*EntityPass*', 'a'),
        (155, 'SOFTWARE_COMPOSITING', 'r', 'thread:SurfaceFlinger', 0, 1, 't', 'eq', 'SurfaceFlinger', 'g'),
        (156, 'SOFTWARE_COMPOSITING', 's', 'has_handle_message_refresh', 30, 1, 's', 'glob', '*handleMessageRefresh*', 'g'),
        (157, 'SOFTWARE_COMPOSITING', 's', 'has_sf_commit', 15, 1, 's', 'glob', '*commit*', 'g'),
        (158, 'SOFTWARE_COMPOSITING', 's', 'has_sf_composite', 15, 1, 's', 'glob', '*composite*', 'g'),
        (159, 'SOFTWARE_COMPOSITING', 's', 'has_validate_display', 20, 1, 's', 'glob', '*validateDisplay*', 'g'),
        (160, 'SOFTWARE_COMPOSITING', 's', 'has_present_display', 20, 1, 's', 'glob', '*presentDisplay*', 'g'),
        (161, 'SOFTWARE_COMPOSITING', 'e', 'slice_pattern:GPU completion*', 0, 1, 's', 'glob', 'GPU completion*', 'g'),
        (162, 'SOFTWARE_COMPOSITING', 'e', 'slice_pattern:*eglSwapBuffers*', 0, 1, 's', 'glob', '*eglSwapBuffers*', 'g'),
        (163, 'SURFACE_CONTROL_API', 'r', 'slice_pattern:*ASurfaceTransaction*', 0, 1, 's', 'glob', '*ASurfaceTransaction*', 'a'),
        (164, 'SURFACE_CONTROL_API', 's', 'has_asurface_control', 30, 5, 's', 'glob', '*ASurfaceControl*', 'a'),
        (165, 'SURFACE_CONTROL_API', 's', 'has_asurface_transaction', 35, 5, 's', 'glob', '*ASurfaceTransaction*', 'a'),
        (166, 'SURFACE_CONTROL_API', 's', 'has_apply_transaction', 20, 1, 's', 'glob', '*ASurfaceTransaction_apply*', 'a'),
        (167, 'SURFACE_CONTROL_API', 's', 'has_native_window', 15, 1, 's', 'glob', '*ANativeWindow*', 'a'),
        (168, 'SURFACEVIEW_BLAST', 's', 'has_surfaceview', 55, 10, 's', 'glob', '*SurfaceView*', 'a'),
        (169, 'SURFACEVIEW_BLAST', 's', 'has_blast', 20, 1, 's', 'glob', '*BLASTBufferQueue*', 'a'),
        (170, 'SURFACEVIEW_BLAST', 's', 'has_gl_thread', 12, 1, 't', 'glob', '*GLThread*', 'a'),
        (171, 'SURFACEVIEW_BLAST', 's', 'has_glsurface_thread', 8, 1, 't', 'glob', '*GLSurface*', 'a'),
        (172, 'SURFACEVIEW_BLAST', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (173, 'SURFACEVIEW_BLAST', 'e', 'thread:CrRendererMain', 0, 1, 't', 'eq', 'CrRendererMain', 'a'),
        (174, 'SURFACEVIEW_BLAST', 'e', 'thread:UnityMain', 0, 1, 't', 'eq', 'UnityMain', 'a'),
        (175, 'SURFACEVIEW_BLAST', 'e', 'thread:UnityGfx', 0, 1, 't', 'eq', 'UnityGfx', 'a'),
        (176, 'TEXTUREVIEW_STANDARD', 's', 'has_surface_texture', 25, 5, 's', 'glob', '*SurfaceTexture*', 'a'),
        (177, 'TEXTUREVIEW_STANDARD', 's', 'has_update_tex_image', 15, 1, 's', 'glob', '*updateTexImage*', 'a'),
        (178, 'TEXTUREVIEW_STANDARD', 's', 'has_on_frame_available', 8, 1, 's', 'glob', '*onFrameAvailable*', 'a'),
        (179, 'TEXTUREVIEW_STANDARD', 's', 'has_render_thread', 20, 1, 't', 'glob', 'RenderThread*', 'a'),
        (180, 'TEXTUREVIEW_STANDARD', 's', 'has_deferred_layer_updater', 8, 1, 's', 'glob', '*DeferredLayerUpdater*', 'a'),
        (181, 'TEXTUREVIEW_STANDARD', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (182, 'TEXTUREVIEW_STANDARD', 'e', 'thread:1.raster', 0, 1, 't', 'eq', '1.raster', 'a'),
        (183, 'TEXTUREVIEW_STANDARD', 'e', 'thread:CrRendererMain', 0, 1, 't', 'eq', 'CrRendererMain', 'a'),
        (184, 'TEXTUREVIEW_STANDARD', 'e', 'slice_pattern:*TBS*', 0, 1, 's', 'glob', '*TBS*', 'a'),
        (185, 'TEXTUREVIEW_STANDARD', 'e', 'slice_pattern:*X5*', 0, 1, 's', 'glob', '*X5*', 'a'),
        (186, 'TEXTUREVIEW_STANDARD', 'e', 'slice_pattern:*UCCore*', 0, 1, 's', 'glob', '*UCCore*', 'a'),
        (187, 'VARIABLE_REFRESH_RATE', 'r', 'thread:SurfaceFlinger', 0, 1, 't', 'eq', 'SurfaceFlinger', 'g'),
        (188, 'VARIABLE_REFRESH_RATE', 's', 'has_frame_timeline', 40, 5, 's', 'glob', '*FrameTimeline*', 'g'),
        (189, 'VARIABLE_REFRESH_RATE', 's', 'has_set_frame_rate', 15, 1, 's', 'glob', '*setFrameRate*', 'g'),
        (190, 'VARIABLE_REFRESH_RATE', 's', 'has_frame_rate_vote', 5, 1, 's', 'glob', '*FrameRateVote*', 'g'),
        (191, 'VARIABLE_REFRESH_RATE', 's', 'has_set_frame_rate_category', 6, 1, 's', 'glob', '*setFrameRateCategory*', 'g'),
        (192, 'VARIABLE_REFRESH_RATE', 's', 'has_frame_rate_category', 6, 1, 's', 'glob', '*FRAME_RATE_CATEGORY*', 'g'),
        (193, 'VARIABLE_REFRESH_RATE', 's', 'has_display_mode', 8, 1, 's', 'glob', '*DisplayMode*', 'g'),
        (194, 'VARIABLE_REFRESH_RATE', 's', 'has_refresh_rate', 7, 1, 's', 'glob', '*RefreshRate*', 'g'),
        (195, 'VIDEO_OVERLAY_HWC', 's', 'has_hwc', 20, 1, 's', 'glob', '*HWC*', 'g'),
        (196, 'VIDEO_OVERLAY_HWC', 's', 'has_hardware_composer', 15, 1, 's', 'glob', '*HardwareComposer*', 'g'),
        (197, 'VIDEO_OVERLAY_HWC', 's', 'has_video', 15, 1, 's', 'glob', '*Video*', 'g'),
        (198, 'VIDEO_OVERLAY_HWC', 's', 'has_mediacodec', 20, 1, 's', 'glob', '*MediaCodec*', 'g'),
        (199, 'VULKAN_NATIVE', 'r', 'slice_pattern:*vkQueuePresentKHR*', 0, 5, 's', 'glob', '*vkQueuePresentKHR*', 'a'),
        (200, 'VULKAN_NATIVE', 's', 'has_vk_present', 60, 1, 's', 'glob', '*vkQueuePresentKHR*', 'a'),
        (201, 'VULKAN_NATIVE', 's', 'has_vk_cmd', 20, 10, 's', 'glob', '*vkCmd*', 'a'),
        (202, 'VULKAN_NATIVE', 's', 'has_swappy', 20, 1, 's', 'glob', '*Swappy*', 'a'),
        (203, 'VULKAN_NATIVE', 's', 'has_vulkan_thread', 6, 1, 't', 'glob', '*Vulkan*', 'a'),
        (204, 'VULKAN_NATIVE', 's', 'has_vkqueue_thread', 4, 1, 't', 'glob', '*VkQueue*', 'a'),
        (205, 'VULKAN_NATIVE', 's', 'has_vk_acquire', 5, 1, 's', 'glob', '*vkAcquireNextImage*', 'a'),
        (206, 'WEBVIEW_GL_FUNCTOR', 'r', 'thread:RenderThread', 0, 1, 't', 'eq', 'RenderThread', 'a'),
        (207, 'WEBVIEW_GL_FUNCTOR', 's', 'has_draw_gl', 25, 1, 's', 'glob', '*DrawGL*', 'a'),
        (208, 'WEBVIEW_GL_FUNCTOR', 's', 'has_draw_fn_draw_gl', 20, 1, 's', 'glob', '*DrawFn_DrawGL*', 'a'),
        (209, 'WEBVIEW_GL_FUNCTOR', 's', 'has_draw_functor', 15, 1, 's', 'glob', '*DrawFunctor*', 'a'),
        (210, 'WEBVIEW_GL_FUNCTOR', 's', 'has_cr_renderer', 25, 1, 't', 'glob', 'CrRendererMain*', 'a'),
        (211, 'WEBVIEW_GL_FUNCTOR', 's', 'has_render_thread', 10, 1, 't', 'glob', 'RenderThread*', 'a'),
        (212, 'WEBVIEW_GL_FUNCTOR', 'e', 'thread_pattern:VizCompositorThread*', 0, 1, 't', 'glob', 'VizCompositorThread*', 'a'),
        (213, 'WEBVIEW_GL_FUNCTOR', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (214, 'WEBVIEW_SURFACE_CONTROL', 's', 'has_viz_compositor', 55, 1, 't', 'glob', 'VizCompositorThread*', 'a'),
        (215, 'WEBVIEW_SURFACE_CONTROL', 's', 'has_cr_renderer', 12, 1, 't', 'glob', 'CrRendererMain*', 'a'),
        (216, 'WEBVIEW_SURFACE_CONTROL', 's', 'has_surface_control', 15, 1, 's', 'glob', '*SurfaceControl*', 'a'),
        (217, 'WEBVIEW_SURFACE_CONTROL', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (218, 'WEBVIEW_SURFACEVIEW_WRAPPER', 's', 'has_webview', 30, 1, 's', 'glob', '*WebView*', 'a'),
        (219, 'WEBVIEW_SURFACEVIEW_WRAPPER', 's', 'has_webview_core', 10, 1, 't', 'glob', 'WebViewCore*', 'a'),
        (220, 'WEBVIEW_SURFACEVIEW_WRAPPER', 's', 'has_cr_renderer', 10, 1, 't', 'glob', 'CrRendererMain*', 'a'),
        (221, 'WEBVIEW_SURFACEVIEW_WRAPPER', 's', 'has_surfaceview', 25, 1, 's', 'glob', '*SurfaceView*', 'a'),
        (222, 'WEBVIEW_SURFACEVIEW_WRAPPER', 's', 'has_video', 12, 1, 's', 'glob', '*Video*', 'a'),
        (223, 'WEBVIEW_SURFACEVIEW_WRAPPER', 's', 'has_mediacodec', 13, 1, 's', 'glob', '*MediaCodec*', 'a'),
        (224, 'WEBVIEW_SURFACEVIEW_WRAPPER', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a'),
        (225, 'WEBVIEW_TEXTUREVIEW_CUSTOM', 's', 'has_tbs', 30, 1, 's', 'glob', '*TBS*', 'a'),
        (226, 'WEBVIEW_TEXTUREVIEW_CUSTOM', 's', 'has_x5', 30, 1, 's', 'glob', '*X5*', 'a'),
        (227, 'WEBVIEW_TEXTUREVIEW_CUSTOM', 's', 'has_uccore', 20, 1, 's', 'glob', '*UCCore*', 'a'),
        (228, 'WEBVIEW_TEXTUREVIEW_CUSTOM', 'e', 'thread:1.ui', 0, 1, 't', 'eq', '1.ui', 'a')
      ),
      signal_counts AS (
        SELECT
          sd.signal_id,
          sd.pipeline_id,
          sd.signal_type,
          sd.signal_name,
          sd.weight,
          sd.min_count,
          SUM(
            CASE
              WHEN sd.source = 't' THEN CASE WHEN sd.scope = 'g' THEN COALESCE(tc.global_cnt, 0) ELSE COALESCE(tc.app_cnt, 0) END
              WHEN sd.source = 's' THEN CASE WHEN sd.scope = 'g' THEN COALESCE(sc.global_cnt, 0) ELSE COALESCE(sc.app_cnt, 0) END
              ELSE 0
            END
          ) as cnt
        FROM signal_defs sd
        LEFT JOIN thread_counts tc
          ON sd.source = 't'
         AND (
           (sd.op = 'eq' AND tc.thread_name = sd.pattern)
           OR (sd.op = 'glob' AND tc.thread_name GLOB sd.pattern)
         )
        LEFT JOIN slice_counts sc
          ON sd.source = 's'
         AND (
           (sd.op = 'eq' AND sc.slice_name = sd.pattern)
           OR (sd.op = 'glob' AND sc.slice_name GLOB sd.pattern)
         )
        GROUP BY sd.signal_id, sd.pipeline_id, sd.signal_type, sd.signal_name, sd.weight, sd.min_count
      ),
      signal_agg AS (
        SELECT
          pipeline_id,
          MIN(
            CASE
              WHEN signal_type = 'r' THEN CASE WHEN cnt >= min_count THEN 1 ELSE 0 END
              ELSE 1
            END
          ) as required_ok,
          MAX(
            CASE
              WHEN signal_type = 'e' THEN CASE WHEN cnt > 0 THEN 1 ELSE 0 END
              ELSE 0
            END
          ) as excluded,
          SUM(CASE WHEN signal_type = 's' THEN weight ELSE 0 END) as total_weight,
          SUM(CASE WHEN signal_type = 's' AND cnt >= min_count THEN weight ELSE 0 END) as matched_weight
        FROM signal_counts
        GROUP BY pipeline_id
      ),
      pipeline_scores AS (
        SELECT
          pl.pipeline_id,
          COALESCE(sa.required_ok, 1) as required_ok,
          COALESCE(sa.excluded, 0) as excluded,
          COALESCE(sa.total_weight, 0) as total_weight,
          COALESCE(sa.matched_weight, 0) as matched_weight
        FROM pipeline_list pl
        LEFT JOIN signal_agg sa ON sa.pipeline_id = pl.pipeline_id
      ),
      scores AS (
        SELECT
          pipeline_id,
          required_ok,
          excluded,
          total_weight,
          matched_weight,
          CASE
            WHEN required_ok = 1 AND excluded = 0 AND total_weight > 0
            THEN matched_weight * 1.0 / total_weight
            ELSE 0
          END as score
        FROM pipeline_scores
      )
      SELECT * FROM scores

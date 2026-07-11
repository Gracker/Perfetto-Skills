-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH thread_data AS (SELECT * FROM ${thread_signals}),
     slice_data AS (SELECT * FROM ${slice_signals}),
     scores AS (
  SELECT
    -- =====================================================================
    -- HWUI Family
    -- =====================================================================
    -- ANDROID_VIEW_STANDARD_BLAST: HWUI + BLAST
    -- Max 0.90: HWUI is the most common Android rendering pipeline
    CASE
      WHEN (SELECT render_thread_count FROM thread_data) > 0
           AND (SELECT blast_bq_count + apply_transaction_count FROM slice_data) > 0
           AND (SELECT flutter_ui_count FROM thread_data) = 0
           AND (SELECT chrome_count + cr_renderer_count + viz_compositor_count FROM thread_data) = 0
           AND (SELECT unity_main_count + unity_gfx_count + unreal_game_count + unreal_rhi_count + godot_count FROM thread_data) = 0
      THEN 0.45 +
           CASE WHEN (SELECT draw_frame_count FROM slice_data) > 0 THEN 0.20 ELSE 0 END +
           CASE WHEN (SELECT choreographer_count FROM slice_data) > 0 THEN 0.15 ELSE 0 END +
           CASE WHEN (SELECT sync_frame_count FROM slice_data) > 0 THEN 0.10 ELSE 0 END
      ELSE 0
    END as score_android_view_standard_blast,

    -- ANDROID_VIEW_STANDARD_LEGACY: HWUI + Legacy (no BLAST)
    -- Max 0.75: pre-Android 12, increasingly rare but still valid
    CASE
      WHEN (SELECT render_thread_count FROM thread_data) > 0
           AND (SELECT blast_bq_count + apply_transaction_count FROM slice_data) = 0
           AND (SELECT queue_buffer_count FROM slice_data) > 0
           AND (SELECT flutter_ui_count FROM thread_data) = 0
           AND (SELECT chrome_count + cr_renderer_count + viz_compositor_count FROM thread_data) = 0
           AND (SELECT unity_main_count + unity_gfx_count + unreal_game_count + unreal_rhi_count + godot_count FROM thread_data) = 0
      THEN 0.40 +
           CASE WHEN (SELECT draw_frame_count FROM slice_data) > 0 THEN 0.20 ELSE 0 END +
           CASE WHEN (SELECT choreographer_count FROM slice_data) > 0 THEN 0.15 ELSE 0 END
      ELSE 0
    END as score_android_view_standard_legacy,

    -- ANDROID_VIEW_SOFTWARE: No RenderThread, CPU Skia
    CASE
      WHEN (SELECT render_thread_count FROM thread_data) = 0
           AND (SELECT lock_canvas_count FROM slice_data) > 0
      THEN 0.60 + CASE WHEN (SELECT draw_frame_count FROM slice_data) = 0 THEN 0.20 ELSE 0 END
      ELSE 0
    END as score_android_view_software,

    -- ANDROID_VIEW_MIXED: View + SurfaceView hybrid
    CASE
      WHEN (SELECT render_thread_count FROM thread_data) > 0
           AND (SELECT surfaceview_count FROM slice_data) > 0
           AND (SELECT draw_frame_count FROM slice_data) > 0
           AND (SELECT chrome_count + cr_renderer_count + viz_compositor_count FROM thread_data) = 0
      THEN 0.50 + CASE WHEN (SELECT media_thread_count FROM thread_data) > 0 THEN 0.20 ELSE 0 END
      ELSE 0
    END as score_android_view_mixed,

    -- ANDROID_VIEW_MULTI_WINDOW: Dialog/PopupWindow serialization
    CASE
      WHEN (SELECT dialog_count FROM slice_data) > 0
      THEN 0.40 + CASE WHEN (SELECT render_thread_count FROM thread_data) > 0 THEN 0.20 ELSE 0 END
      ELSE 0
    END as score_android_view_multi_window,

    -- =====================================================================
    -- Surface-Based
    -- =====================================================================
    -- ANDROID_PIP_FREEFORM: PIP/Freeform
    CASE
      WHEN (SELECT pip_count FROM slice_data) > 0
      THEN 0.70
      ELSE 0
    END as score_android_pip_freeform,

    -- SURFACEVIEW_BLAST: Independent SurfaceView + BLAST
    CASE
      WHEN (SELECT surfaceview_count FROM slice_data) > 10
           AND (SELECT blast_bq_count FROM slice_data) > 0
           AND (SELECT flutter_ui_count FROM thread_data) = 0
           AND (SELECT chrome_count + cr_renderer_count FROM thread_data) = 0
           AND (SELECT unity_main_count + unity_gfx_count + unreal_game_count + unreal_rhi_count + godot_count FROM thread_data) = 0
      THEN 0.55 + CASE WHEN (SELECT gl_thread_count FROM thread_data) > 0 THEN 0.20 ELSE 0 END
      ELSE 0
    END as score_surfaceview_blast,

    -- TEXTUREVIEW_STANDARD: SurfaceTexture updateTexImage
    CASE
      WHEN (SELECT texture_view_count FROM slice_data) > 5
           AND (SELECT flutter_ui_count FROM thread_data) = 0
           AND (SELECT custom_webview_count FROM slice_data) = 0
      THEN 0.60 + CASE WHEN (SELECT render_thread_count FROM thread_data) > 0 THEN 0.20 ELSE 0 END
      ELSE 0
    END as score_textureview_standard,

    -- SURFACE_CONTROL_API: NDK SurfaceControl
    CASE
      WHEN (SELECT surface_control_count FROM slice_data) > 10
      THEN 0.65 + CASE WHEN (SELECT apply_transaction_count FROM slice_data) > 0 THEN 0.20 ELSE 0 END
      ELSE 0
    END as score_surface_control_api,

    -- =====================================================================
    -- Graphics APIs
    -- =====================================================================
    -- OPENGL_ES: GLES/EGL rendering
    CASE
      WHEN (SELECT egl_swap_count FROM slice_data) > 0
           AND (SELECT vk_present_count FROM slice_data) = 0
           AND (SELECT angle_count FROM slice_data) = 0
           AND (SELECT flutter_ui_count FROM thread_data) = 0
           AND (SELECT chrome_count + cr_renderer_count + viz_compositor_count FROM thread_data) = 0
           AND (SELECT unity_main_count + unity_gfx_count + unreal_game_count + unreal_rhi_count + godot_count FROM thread_data) = 0
      THEN 0.50 +
           CASE WHEN (SELECT gl_draw_count FROM slice_data) > 0 THEN 0.20 ELSE 0 END +
           CASE WHEN (SELECT gl_thread_count FROM thread_data) > 0 THEN 0.15 ELSE 0 END
      ELSE 0
    END as score_opengl_es,

    -- VULKAN_NATIVE: Native Vulkan
    CASE
      WHEN (SELECT vk_present_count FROM slice_data) > 0
           OR (SELECT vk_cmd_count FROM slice_data) > 10
      THEN 0.60 +
           CASE WHEN (SELECT swappy_count FROM slice_data) > 0 THEN 0.20 ELSE 0 END +
           CASE WHEN (SELECT vulkan_thread_count FROM thread_data) > 0 THEN 0.10 ELSE 0 END
      ELSE 0
    END as score_vulkan_native,

    -- ANGLE_GLES_VULKAN: ANGLE translation layer
    CASE
      WHEN (SELECT angle_count FROM slice_data) > 0
      THEN 0.80
      ELSE 0
    END as score_angle_gles_vulkan,

    -- =====================================================================
    -- Flutter
    -- =====================================================================
    -- FLUTTER_SURFACEVIEW_IMPELLER: Flutter + Impeller
    CASE
      WHEN (SELECT flutter_ui_count FROM thread_data) > 0
           AND (SELECT impeller_entity_count FROM slice_data) > 0
      THEN 0.80 + CASE WHEN (SELECT flutter_raster_count FROM thread_data) > 0 THEN 0.15 ELSE 0 END
      ELSE 0
    END as score_flutter_surfaceview_impeller,

    -- FLUTTER_SURFACEVIEW_SKIA: Flutter + Skia
    CASE
      WHEN (SELECT flutter_ui_count FROM thread_data) > 0
           AND (SELECT skia_gpu_count FROM slice_data) > 0
           AND (SELECT impeller_entity_count FROM slice_data) = 0
      THEN 0.75 + CASE WHEN (SELECT flutter_raster_count FROM thread_data) > 0 THEN 0.15 ELSE 0 END
      ELSE 0
    END as score_flutter_surfaceview_skia,

    -- FLUTTER_TEXTUREVIEW: Flutter TextureView rendering
    CASE
      WHEN (SELECT flutter_ui_count FROM thread_data) > 0
           AND (SELECT texture_view_count FROM slice_data) > 5
      THEN 0.75 +
           CASE WHEN (SELECT render_thread_count FROM thread_data) > 0 THEN 0.10 ELSE 0 END
      ELSE 0
    END as score_flutter_textureview,

    -- =====================================================================
    -- WebView
    -- =====================================================================
    -- WEBVIEW_GL_FUNCTOR: App RT sync wait
    CASE
      WHEN (SELECT draw_gl_functor_count FROM slice_data) > 0
           OR ((SELECT cr_renderer_count FROM thread_data) > 0
               AND (SELECT render_thread_count FROM thread_data) > 0
               AND (SELECT viz_compositor_count FROM thread_data) = 0)
      THEN 0.70 + CASE WHEN (SELECT blink_count + v8_count FROM slice_data) > 0 THEN 0.15 ELSE 0 END
      ELSE 0
    END as score_webview_gl_functor,

    -- WEBVIEW_SURFACE_CONTROL: Viz/OOP-R/SC
    CASE
      WHEN (SELECT viz_compositor_count FROM thread_data) > 0
      THEN 0.75 + CASE WHEN (SELECT surface_control_count FROM slice_data) > 0 THEN 0.15 ELSE 0 END
      ELSE 0
    END as score_webview_surface_control,

    -- WEBVIEW_SURFACEVIEW_WRAPPER: Full-screen video
    CASE
      WHEN (SELECT webview_slice_count FROM slice_data) > 0
           OR (SELECT webview_core_count FROM thread_data) > 0
           AND (SELECT surfaceview_count FROM slice_data) > 0
           AND (SELECT video_slice_count FROM slice_data) > 0
      THEN 0.65
      ELSE 0
    END as score_webview_surfaceview_wrapper,

    -- WEBVIEW_TEXTUREVIEW_CUSTOM: X5/UC custom kernel
    CASE
      WHEN (SELECT custom_webview_count FROM slice_data) > 0
      THEN 0.80
      ELSE 0
    END as score_webview_textureview_custom,

    -- =====================================================================
    -- Specialized
    -- =====================================================================
    -- GAME_ENGINE: Unity/Unreal/Godot
    CASE
      WHEN (SELECT unity_main_count + unity_gfx_count FROM thread_data) > 0
      THEN 0.85
      WHEN (SELECT unreal_game_count + unreal_rhi_count FROM thread_data) > 0
      THEN 0.85
      WHEN (SELECT godot_count FROM thread_data) > 0
      THEN 0.80
      WHEN (SELECT unity_slice_count + unity_player_loop_count FROM slice_data) > 0
      THEN 0.75
      WHEN (SELECT unreal_slice_count FROM slice_data) > 0
      THEN 0.75
      ELSE 0
    END as score_game_engine,

    -- CAMERA_PIPELINE: Camera2/HAL3
    CASE
      WHEN (SELECT camera_thread_count FROM thread_data) > 0
           AND (SELECT camera_slice_count + capture_session_count FROM slice_data) > 0
      THEN 0.70
      ELSE 0
    END as score_camera_pipeline,

    -- VIDEO_OVERLAY_HWC: HWC video layer
    CASE
      WHEN (SELECT hwc_slice_count FROM slice_data) > 0
           AND (SELECT video_slice_count FROM slice_data) > 0
      THEN 0.65
      ELSE 0
    END as score_video_overlay_hwc,

    -- HARDWARE_BUFFER_RENDERER: Android 14+ HBR
    CASE
      WHEN (SELECT hbr_count FROM slice_data) > 0
      THEN 0.75
      ELSE 0
    END as score_hardware_buffer_renderer,

    -- VARIABLE_REFRESH_RATE: VRR/ARR
    CASE
      WHEN (SELECT frame_timeline_count FROM slice_data) > 0
           AND (SELECT frame_rate_count FROM slice_data) > 0
      THEN 0.60
      WHEN (SELECT frame_timeline_count FROM slice_data) > 5
      THEN 0.40
      ELSE 0
    END as score_variable_refresh_rate
)
SELECT * FROM scores

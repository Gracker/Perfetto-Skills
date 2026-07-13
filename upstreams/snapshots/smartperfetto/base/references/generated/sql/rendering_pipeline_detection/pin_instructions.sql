-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH pipeline AS (SELECT * FROM ${pipeline_result})
SELECT
  (SELECT primary_pipeline_id FROM pipeline) as pipeline_id,
  CASE (SELECT primary_pipeline_id FROM pipeline)
    -- HWUI Family
    WHEN 'ANDROID_VIEW_STANDARD_BLAST' THEN 'main|RenderThread|SurfaceFlinger|VSYNC'
    WHEN 'ANDROID_VIEW_STANDARD_LEGACY' THEN 'main|RenderThread|SurfaceFlinger'
    WHEN 'ANDROID_VIEW_SOFTWARE' THEN 'main|SurfaceFlinger'
    WHEN 'ANDROID_VIEW_MIXED' THEN 'main|RenderThread|SurfaceFlinger|GLThread'
    WHEN 'ANDROID_VIEW_MULTI_WINDOW' THEN 'main|RenderThread|SurfaceFlinger'
    -- Surface-Based
    WHEN 'SURFACEVIEW_BLAST' THEN 'GLThread|SurfaceFlinger|VSYNC'
    WHEN 'TEXTUREVIEW_STANDARD' THEN 'main|RenderThread|SurfaceFlinger'
    WHEN 'SURFACE_CONTROL_API' THEN 'main|SurfaceFlinger|SurfaceControl'
    -- Graphics APIs
    WHEN 'OPENGL_ES' THEN 'GLThread|RenderThread|SurfaceFlinger'
    WHEN 'VULKAN_NATIVE' THEN 'main|RenderThread|SurfaceFlinger|VkQueue'
    WHEN 'ANGLE_GLES_VULKAN' THEN 'main|RenderThread|SurfaceFlinger'
    -- Flutter
    WHEN 'FLUTTER_SURFACEVIEW_IMPELLER' THEN '1.ui|1.raster|io.flutter|SurfaceFlinger'
    WHEN 'FLUTTER_SURFACEVIEW_SKIA' THEN '1.ui|1.raster|io.flutter|SurfaceFlinger'
    WHEN 'FLUTTER_TEXTUREVIEW' THEN '1.ui|1.raster|JNISurfaceTextu|RenderThread|SurfaceFlinger'
    -- WebView
    WHEN 'WEBVIEW_GL_FUNCTOR' THEN 'main|RenderThread|CrRendererMain|SurfaceFlinger'
    WHEN 'WEBVIEW_SURFACE_CONTROL' THEN 'CrRendererMain|VizCompositor|SurfaceFlinger'
    WHEN 'WEBVIEW_SURFACEVIEW_WRAPPER' THEN 'main|CrRendererMain|SurfaceFlinger'
    WHEN 'WEBVIEW_TEXTUREVIEW_CUSTOM' THEN 'main|RenderThread|CrRendererMain|SurfaceFlinger'
    -- Specialized
    WHEN 'GAME_ENGINE' THEN 'UnityMain|UnityGfx|GameThread|RenderThread|SurfaceFlinger'
    WHEN 'CAMERA_PIPELINE' THEN 'CameraSession|SurfaceFlinger'
    WHEN 'VIDEO_OVERLAY_HWC' THEN 'MediaCodec|SurfaceFlinger|HWC'
    WHEN 'HARDWARE_BUFFER_RENDERER' THEN 'main|SurfaceFlinger'
    WHEN 'VARIABLE_REFRESH_RATE' THEN 'main|RenderThread|SurfaceFlinger|VSYNC'
    ELSE 'main|RenderThread|SurfaceFlinger'
  END as pin_patterns

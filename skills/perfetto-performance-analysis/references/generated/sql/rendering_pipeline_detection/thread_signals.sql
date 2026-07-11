-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH app_threads AS (
  SELECT DISTINCT
    t.name as thread_name,
    p.name as process_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE t.name IS NOT NULL
    AND (p.name GLOB '${package}*' OR '${package}' = '')
)
SELECT
  -- Flutter signals
  SUM(CASE WHEN thread_name IN ('ui', '1.ui') THEN 1 ELSE 0 END) as flutter_ui_count,
  SUM(CASE WHEN thread_name GLOB '*raster*' OR thread_name = '1.raster' THEN 1 ELSE 0 END) as flutter_raster_count,
  SUM(CASE WHEN thread_name GLOB '*io.flutter*' THEN 1 ELSE 0 END) as flutter_io_count,
  SUM(CASE WHEN thread_name GLOB '*io.flutter.impeller*' THEN 1 ELSE 0 END) as flutter_impeller_thread_count,
  -- Standard Android signals
  SUM(CASE WHEN thread_name = 'RenderThread' THEN 1 ELSE 0 END) as render_thread_count,
  SUM(CASE WHEN thread_name = 'main' THEN 1 ELSE 0 END) as main_thread_count,
  -- WebView/Chromium signals
  SUM(CASE WHEN thread_name GLOB '*Chrome*' THEN 1 ELSE 0 END) as chrome_count,
  SUM(CASE WHEN thread_name GLOB '*CrRenderer*' THEN 1 ELSE 0 END) as cr_renderer_count,
  SUM(CASE WHEN thread_name GLOB '*CompositorTileW*' THEN 1 ELSE 0 END) as compositor_tile_count,
  SUM(CASE WHEN thread_name GLOB '*VizCompositor*' THEN 1 ELSE 0 END) as viz_compositor_count,
  SUM(CASE WHEN thread_name GLOB '*WebViewCore*' THEN 1 ELSE 0 END) as webview_core_count,
  -- Game Engine signals
  SUM(CASE WHEN thread_name GLOB '*UnityMain*' THEN 1 ELSE 0 END) as unity_main_count,
  SUM(CASE WHEN thread_name GLOB '*UnityGfx*' THEN 1 ELSE 0 END) as unity_gfx_count,
  SUM(CASE WHEN thread_name GLOB '*GameThread*' THEN 1 ELSE 0 END) as unreal_game_count,
  SUM(CASE WHEN thread_name GLOB '*RHIThread*' THEN 1 ELSE 0 END) as unreal_rhi_count,
  SUM(CASE WHEN thread_name GLOB '*GodotMain*' THEN 1 ELSE 0 END) as godot_count,
  -- Surface-related signals
  SUM(CASE WHEN thread_name GLOB '*GLThread*' OR thread_name GLOB '*GLSurface*' THEN 1 ELSE 0 END) as gl_thread_count,
  SUM(CASE WHEN thread_name GLOB '*MediaCodec*' OR thread_name GLOB '*Decoder*' THEN 1 ELSE 0 END) as media_thread_count,
  SUM(CASE WHEN thread_name GLOB '*Camera*' THEN 1 ELSE 0 END) as camera_thread_count,
  -- Vulkan signals
  SUM(CASE WHEN thread_name GLOB '*Vulkan*' OR thread_name GLOB '*VkQueue*' THEN 1 ELSE 0 END) as vulkan_thread_count
FROM app_threads

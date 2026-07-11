-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH scores AS (SELECT * FROM ${pipeline_scores}),
     all_scores AS (
  SELECT 'ANDROID_VIEW_STANDARD_BLAST' as pipeline_id, score_android_view_standard_blast as score FROM scores
  UNION ALL SELECT 'ANDROID_VIEW_STANDARD_LEGACY', score_android_view_standard_legacy FROM scores
  UNION ALL SELECT 'ANDROID_VIEW_SOFTWARE', score_android_view_software FROM scores
  UNION ALL SELECT 'ANDROID_VIEW_MIXED', score_android_view_mixed FROM scores
  UNION ALL SELECT 'ANDROID_VIEW_MULTI_WINDOW', score_android_view_multi_window FROM scores
  UNION ALL SELECT 'ANDROID_PIP_FREEFORM', score_android_pip_freeform FROM scores
  UNION ALL SELECT 'SURFACEVIEW_BLAST', score_surfaceview_blast FROM scores
  UNION ALL SELECT 'TEXTUREVIEW_STANDARD', score_textureview_standard FROM scores
  UNION ALL SELECT 'SURFACE_CONTROL_API', score_surface_control_api FROM scores
  UNION ALL SELECT 'OPENGL_ES', score_opengl_es FROM scores
  UNION ALL SELECT 'VULKAN_NATIVE', score_vulkan_native FROM scores
  UNION ALL SELECT 'ANGLE_GLES_VULKAN', score_angle_gles_vulkan FROM scores
  UNION ALL SELECT 'FLUTTER_SURFACEVIEW_IMPELLER', score_flutter_surfaceview_impeller FROM scores
  UNION ALL SELECT 'FLUTTER_SURFACEVIEW_SKIA', score_flutter_surfaceview_skia FROM scores
  UNION ALL SELECT 'FLUTTER_TEXTUREVIEW', score_flutter_textureview FROM scores
  UNION ALL SELECT 'WEBVIEW_GL_FUNCTOR', score_webview_gl_functor FROM scores
  UNION ALL SELECT 'WEBVIEW_SURFACE_CONTROL', score_webview_surface_control FROM scores
  UNION ALL SELECT 'WEBVIEW_SURFACEVIEW_WRAPPER', score_webview_surfaceview_wrapper FROM scores
  UNION ALL SELECT 'WEBVIEW_TEXTUREVIEW_CUSTOM', score_webview_textureview_custom FROM scores
  UNION ALL SELECT 'GAME_ENGINE', score_game_engine FROM scores
  UNION ALL SELECT 'CAMERA_PIPELINE', score_camera_pipeline FROM scores
  UNION ALL SELECT 'VIDEO_OVERLAY_HWC', score_video_overlay_hwc FROM scores
  UNION ALL SELECT 'HARDWARE_BUFFER_RENDERER', score_hardware_buffer_renderer FROM scores
  UNION ALL SELECT 'VARIABLE_REFRESH_RATE', score_variable_refresh_rate FROM scores
),
ranked AS (
  SELECT
    pipeline_id,
    score,
    ROW_NUMBER() OVER (ORDER BY score DESC) as rank
  FROM all_scores
  WHERE score > 0.3
),
primary_pipeline AS (
  SELECT pipeline_id, score FROM ranked WHERE rank = 1
),
candidates AS (
  SELECT pipeline_id, score FROM ranked WHERE rank <= 5
),
features AS (
  SELECT pipeline_id, score FROM all_scores
  WHERE pipeline_id IN ('VARIABLE_REFRESH_RATE', 'VIDEO_OVERLAY_HWC', 'SURFACE_CONTROL_API')
    AND score > 0.3
),
candidate_list AS (
  SELECT GROUP_CONCAT(pipeline_id || ':' || ROUND(score, 2), '; ') as candidates_list
  FROM candidates
  GROUP BY 'all_candidates'
),
feature_list AS (
  SELECT GROUP_CONCAT(pipeline_id || ':' || ROUND(score, 2), '; ') as features_list
  FROM features
  GROUP BY 'all_features'
)
SELECT
  COALESCE((SELECT pipeline_id FROM primary_pipeline), 'ANDROID_VIEW_STANDARD_BLAST') as primary_pipeline_id,
  COALESCE((SELECT score FROM primary_pipeline), 0.50) as primary_confidence,
  (SELECT candidates_list FROM candidate_list) as candidates_list,
  (SELECT features_list FROM feature_list) as features_list,
  CASE COALESCE((SELECT pipeline_id FROM primary_pipeline), 'ANDROID_VIEW_STANDARD_BLAST')
    WHEN 'ANDROID_VIEW_STANDARD_BLAST' THEN 'rendering_pipelines/android_view_standard.md'
    WHEN 'ANDROID_VIEW_STANDARD_LEGACY' THEN 'rendering_pipelines/android_view_standard.md'
    WHEN 'ANDROID_VIEW_SOFTWARE' THEN 'rendering_pipelines/android_view_software.md'
    WHEN 'ANDROID_VIEW_MIXED' THEN 'rendering_pipelines/android_view_mixed.md'
    WHEN 'ANDROID_VIEW_MULTI_WINDOW' THEN 'rendering_pipelines/android_view_multi_window.md'
    WHEN 'ANDROID_PIP_FREEFORM' THEN 'rendering_pipelines/android_pip_freeform.md'
    WHEN 'SURFACEVIEW_BLAST' THEN 'rendering_pipelines/surfaceview.md'
    WHEN 'TEXTUREVIEW_STANDARD' THEN 'rendering_pipelines/textureview.md'
    WHEN 'SURFACE_CONTROL_API' THEN 'rendering_pipelines/surface_control_api.md'
    WHEN 'OPENGL_ES' THEN 'rendering_pipelines/opengl_es.md'
    WHEN 'VULKAN_NATIVE' THEN 'rendering_pipelines/vulkan_native.md'
    WHEN 'ANGLE_GLES_VULKAN' THEN 'rendering_pipelines/angle_gles_vulkan.md'
    WHEN 'FLUTTER_SURFACEVIEW_IMPELLER' THEN 'rendering_pipelines/flutter_surfaceview.md'
    WHEN 'FLUTTER_SURFACEVIEW_SKIA' THEN 'rendering_pipelines/flutter_surfaceview.md'
    WHEN 'FLUTTER_TEXTUREVIEW' THEN 'rendering_pipelines/flutter_textureview.md'
    WHEN 'WEBVIEW_GL_FUNCTOR' THEN 'rendering_pipelines/webview_gl_functor.md'
    WHEN 'WEBVIEW_SURFACE_CONTROL' THEN 'rendering_pipelines/webview_surface_control.md'
    WHEN 'WEBVIEW_SURFACEVIEW_WRAPPER' THEN 'rendering_pipelines/webview_surfaceview_wrapper.md'
    WHEN 'WEBVIEW_TEXTUREVIEW_CUSTOM' THEN 'rendering_pipelines/webview_textureview_custom.md'
    WHEN 'GAME_ENGINE' THEN 'rendering_pipelines/game_engine.md'
    WHEN 'CAMERA_PIPELINE' THEN 'rendering_pipelines/camera_pipeline.md'
    WHEN 'VIDEO_OVERLAY_HWC' THEN 'rendering_pipelines/video_overlay_hwc.md'
    WHEN 'HARDWARE_BUFFER_RENDERER' THEN 'rendering_pipelines/hardware_buffer_renderer.md'
    WHEN 'VARIABLE_REFRESH_RATE' THEN 'rendering_pipelines/variable_refresh_rate.md'
    ELSE 'rendering_pipelines/android_view_standard.md'
  END as doc_path

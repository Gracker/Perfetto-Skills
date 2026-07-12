-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH slice_data AS (SELECT * FROM ${slice_signals}),
     thread_data AS (SELECT * FROM ${thread_signals})
SELECT
  -- Buffer Mode
  CASE
    WHEN (SELECT blast_bq_count + apply_transaction_count FROM slice_data) > 0 THEN 'BLAST'
    WHEN (SELECT queue_buffer_count FROM slice_data) > 0 THEN 'LEGACY'
    ELSE 'UNKNOWN'
  END as buffer_mode,
  -- Flutter Engine (slice-based primary, thread-based fallback)
  CASE
    WHEN (SELECT impeller_entity_count FROM slice_data) > 0 THEN 'IMPELLER'
    WHEN (SELECT flutter_impeller_thread_count FROM thread_data) > 0 THEN 'IMPELLER'
    WHEN (SELECT skia_gpu_count FROM slice_data) > 0 THEN 'SKIA'
    WHEN (SELECT flutter_ui_count FROM thread_data) > 0 THEN 'UNKNOWN'
    ELSE 'N/A'
  END as flutter_engine,
  -- WebView Mode
  CASE
    WHEN (SELECT viz_compositor_count FROM thread_data) > 0 THEN 'SURFACE_CONTROL'
    WHEN (SELECT draw_gl_functor_count FROM slice_data) > 0 THEN 'GL_FUNCTOR'
    WHEN (SELECT custom_webview_count FROM slice_data) > 0 THEN 'TEXTUREVIEW_CUSTOM'
    WHEN (SELECT webview_slice_count FROM slice_data) > 0 AND (SELECT surfaceview_count FROM slice_data) > 0 THEN 'SURFACEVIEW_WRAPPER'
    WHEN (SELECT chrome_count + cr_renderer_count FROM thread_data) > 0 THEN 'UNKNOWN'
    ELSE 'N/A'
  END as webview_mode,
  -- Game Engine
  CASE
    WHEN (SELECT unity_main_count FROM thread_data) > 0 THEN 'UNITY'
    WHEN (SELECT unreal_game_count FROM thread_data) > 0 THEN 'UNREAL'
    WHEN (SELECT godot_count FROM thread_data) > 0 THEN 'GODOT'
    ELSE 'N/A'
  END as game_engine

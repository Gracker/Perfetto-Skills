-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH slice_data AS (SELECT * FROM ${slice_signals}),
     thread_data AS (SELECT * FROM ${thread_signals})
SELECT
  -- Check for common missing data
  CASE WHEN (SELECT draw_frame_count FROM slice_data) = 0 THEN 'gfx:RenderThread slices missing - add atrace category: gfx' ELSE NULL END as hint_gfx,
  CASE WHEN (SELECT choreographer_count FROM slice_data) = 0 THEN 'Choreographer slices missing - add atrace category: input' ELSE NULL END as hint_input,
  CASE WHEN (SELECT blast_bq_count FROM slice_data) = 0
       AND (SELECT queue_buffer_count FROM slice_data) = 0
  THEN 'BufferQueue slices missing - add atrace category: binder_driver' ELSE NULL END as hint_buffer,
  CASE WHEN NOT EXISTS (SELECT 1 FROM slice WHERE name GLOB '*SurfaceFlinger*' LIMIT 1)
  THEN 'SurfaceFlinger slices missing - add atrace category: sf or run as root' ELSE NULL END as hint_sf,
  CASE WHEN (SELECT frame_timeline_count FROM slice_data) = 0
  THEN 'FrameTimeline missing - add ftrace event: surfaceflinger/frametimeline' ELSE NULL END as hint_timeline

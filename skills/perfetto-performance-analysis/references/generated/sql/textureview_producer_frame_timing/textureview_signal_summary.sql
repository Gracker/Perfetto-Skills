-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/textureview_producer_frame_timing.skill.yaml
-- Source SHA-256: a2c34451c741e02fc6d13ed92dc82fdb910606ab79c16c5996ce90becc55c588
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
textureview_processes AS (
  SELECT DISTINCT p.upid
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name = i.target_process OR p.name GLOB i.target_process || ':*')
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND COALESCE(t.name, '') NOT GLOB '1.ui*'
    AND COALESCE(t.name, '') NOT GLOB '1.raster*'
    AND (
      s.name GLOB '*SurfaceTexture*' OR
      s.name GLOB '*updateTexImage*' OR
      s.name GLOB '*onFrameAvailable*' OR
      s.name GLOB '*DeferredLayerUpdater*'
    )
),
signals AS (
  SELECT
    s.ts,
    s.dur,
    s.name AS slice_name,
    t.name AS thread_name,
    p.name AS process_name,
    CASE
      WHEN s.name GLOB '*updateTexImage*' OR s.name GLOB '*DeferredLayerUpdater*' THEN 'host_consume_update_tex_image'
      WHEN s.name GLOB '*dequeueBuffer*' THEN 'buffer_dequeue'
      WHEN (s.name GLOB '*queueBuffer*' AND s.name NOT GLOB '*dequeueBuffer*')
        OR s.name GLOB '*eglSwapBuffers*'
        OR s.name GLOB '*vkQueuePresent*' THEN 'producer_submit'
      WHEN s.name GLOB '*onFrameAvailable*' THEN 'consumer_notification'
      WHEN s.name GLOB '*SurfaceTexture*' THEN 'surfacetexture_related'
      ELSE 'textureview_related'
    END AS signal_role,
    CASE
      WHEN s.name GLOB '*updateTexImage*' OR s.name GLOB '*DeferredLayerUpdater*' THEN 'update_tex_image'
      WHEN s.name GLOB '*dequeueBuffer*' THEN 'buffer_dequeue'
      WHEN s.name GLOB '*queueBuffer*' AND s.name NOT GLOB '*dequeueBuffer*' THEN 'queue_buffer'
      WHEN s.name GLOB '*eglSwapBuffers*' THEN 'egl_swap_buffers'
      WHEN s.name GLOB '*vkQueuePresent*' THEN 'vk_queue_present'
      WHEN s.name GLOB '*onFrameAvailable*' THEN 'frame_available'
      WHEN s.name GLOB '*SurfaceTexture*' THEN 'surface_texture_related'
      ELSE 'textureview_related'
    END AS signal_type,
    ROUND(s.dur / 1e6, 2) AS dur_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name = i.target_process OR p.name GLOB i.target_process || ':*')
    AND p.upid IN (SELECT upid FROM textureview_processes)
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND s.dur >= 0
    AND COALESCE(t.name, '') NOT GLOB '1.ui*'
    AND COALESCE(t.name, '') NOT GLOB '1.raster*'
    AND (
      s.name GLOB '*SurfaceTexture*' OR
      s.name GLOB '*updateTexImage*' OR
      s.name GLOB '*onFrameAvailable*' OR
      s.name GLOB '*DeferredLayerUpdater*' OR
      s.name GLOB '*queueBuffer*' OR
      s.name GLOB '*eglSwapBuffers*' OR
      s.name GLOB '*vkQueuePresent*'
    )
)
SELECT
  signal_role,
  signal_type,
  process_name,
  COALESCE(thread_name, '<unnamed>') AS thread_name,
  COUNT(*) AS event_count,
  ROUND(AVG(dur_ms), 2) AS avg_dur_ms,
  ROUND(PERCENTILE(dur_ms, 95), 2) AS p95_dur_ms,
  ROUND(MAX(dur_ms), 2) AS max_dur_ms,
  'signal_inventory' AS evidence_scope,
  'event_count_is_not_frame_count_or_jank_count' AS claim_boundary
FROM signals
GROUP BY signal_role, signal_type, process_name, thread_name
ORDER BY event_count DESC, max_dur_ms DESC
LIMIT 50

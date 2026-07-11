-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/textureview_producer_frame_timing.skill.yaml
-- Source SHA-256: 9c4d5fb0a318772a5c5a9b3998e6489d3ca70d4d6ebc88330940731518a9f30a
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
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
      WHEN s.name GLOB '*updateTexImage*' OR s.name GLOB '*DeferredLayerUpdater*' THEN 'host_consume_updateTexImage'
      WHEN s.name GLOB '*onFrameAvailable*' OR s.name GLOB '*SurfaceTexture*' THEN 'producer_frame_available'
      WHEN s.name GLOB '*queueBuffer*' OR s.name GLOB '*eglSwapBuffers*' OR s.name GLOB '*vkQueuePresent*' THEN 'producer_queue_present'
      ELSE 'textureview_related'
    END AS signal_role,
    ROUND(s.dur / 1e6, 2) AS dur_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
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
  process_name,
  COALESCE(thread_name, '<unnamed>') AS thread_name,
  COUNT(*) AS event_count,
  ROUND(AVG(dur_ms), 2) AS avg_dur_ms,
  ROUND(PERCENTILE(dur_ms, 0.95), 2) AS p95_dur_ms,
  ROUND(MAX(dur_ms), 2) AS max_dur_ms
FROM signals
GROUP BY signal_role, process_name, thread_name
ORDER BY event_count DESC, max_dur_ms DESC
LIMIT 50

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/textureview_producer_frame_timing.skill.yaml
-- Source SHA-256: 9c4d5fb0a318772a5c5a9b3998e6489d3ca70d4d6ebc88330940731518a9f30a
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${target_frame_ms}, 16.67) AS target_frame_ms,
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
producer_events AS (
  SELECT
    s.ts,
    s.name AS event_name,
    t.utid,
    COALESCE(t.name, '<unnamed>') AS thread_name,
    p.name AS process_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
    AND p.upid IN (SELECT upid FROM textureview_processes)
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND COALESCE(t.name, '') NOT GLOB '1.ui*'
    AND COALESCE(t.name, '') NOT GLOB '1.raster*'
    AND (
      s.name GLOB '*onFrameAvailable*' OR
      s.name GLOB '*queueBuffer*' OR
      s.name GLOB '*eglSwapBuffers*' OR
      s.name GLOB '*vkQueuePresent*'
    )
),
intervals AS (
  SELECT
    ts,
    event_name,
    LAG(event_name) OVER (PARTITION BY utid ORDER BY ts) AS previous_event_name,
    ts - LAG(ts) OVER (PARTITION BY utid ORDER BY ts) AS interval_ns,
    thread_name,
    process_name
  FROM producer_events
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', interval_ns) AS interval_ns,
  ROUND(interval_ns / 1e6, 2) AS interval_ms,
  CAST(MAX(0, ROUND(interval_ns / ((SELECT target_frame_ms FROM input) * 1000000.0)) - 1) AS INTEGER) AS vsync_missed,
  event_name,
  previous_event_name,
  thread_name,
  process_name,
  CASE
    WHEN interval_ns > (SELECT target_frame_ms * 4 * 1000000.0 FROM input) THEN 'critical'
    WHEN interval_ns > (SELECT target_frame_ms * 2 * 1000000.0 FROM input) THEN 'warning'
    WHEN interval_ns > (SELECT target_frame_ms * 1.5 * 1000000.0 FROM input) THEN 'notice'
    ELSE 'normal'
  END AS rating
FROM intervals
WHERE interval_ns IS NOT NULL
  AND interval_ns > (SELECT target_frame_ms * 1.5 * 1000000.0 FROM input)
ORDER BY interval_ns DESC
LIMIT 100

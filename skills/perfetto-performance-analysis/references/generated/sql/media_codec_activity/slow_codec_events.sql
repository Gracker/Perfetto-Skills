-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/media_codec_activity.skill.yaml
-- Source SHA-256: f9785c4a5b759aab3f1efe3c1d4faede153488cd9f89592428318f926cda0bbb
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${slow_threshold_ms}, 8) AS slow_threshold_ms,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
)
SELECT
  printf('%d', s.ts) AS ts,
  printf('%d', s.dur) AS dur_ns,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  CASE
    WHEN s.name GLOB '*dequeueInputBuffer*' OR s.name GLOB '*queueInputBuffer*' THEN 'input_buffer'
    WHEN s.name GLOB '*dequeueOutputBuffer*' OR s.name GLOB '*releaseOutputBuffer*' THEN 'output_buffer'
    WHEN s.name GLOB '*MediaCodec*' OR t.name GLOB '*MediaCodec*' THEN 'mediacodec'
    WHEN s.name GLOB '*Codec2*' OR t.name GLOB '*Codec2*' OR s.name GLOB '*C2*' THEN 'codec2'
    WHEN s.name GLOB '*OMX*' OR t.name GLOB '*OMX*' THEN 'omx'
    WHEN s.name GLOB '*CCodec*' OR t.name GLOB '*CCodec*' THEN 'ccodec'
    ELSE 'media_codec'
  END AS phase,
  s.name AS slice_name,
  COALESCE(t.name, '<unnamed>') AS thread_name,
  p.name AS process_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
CROSS JOIN input i
WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
  AND s.ts >= i.start_ts
  AND s.ts < i.end_ts
  AND s.dur > i.slow_threshold_ms * 1000000.0
  AND (
    s.name GLOB '*MediaCodec*' OR t.name GLOB '*MediaCodec*' OR
    s.name GLOB '*Codec2*' OR t.name GLOB '*Codec2*' OR
    s.name GLOB '*CCodec*' OR t.name GLOB '*CCodec*' OR
    s.name GLOB '*OMX*' OR t.name GLOB '*OMX*' OR
    s.name GLOB '*dequeueInputBuffer*' OR s.name GLOB '*queueInputBuffer*' OR
    s.name GLOB '*dequeueOutputBuffer*' OR s.name GLOB '*releaseOutputBuffer*'
  )
ORDER BY s.dur DESC
LIMIT 100

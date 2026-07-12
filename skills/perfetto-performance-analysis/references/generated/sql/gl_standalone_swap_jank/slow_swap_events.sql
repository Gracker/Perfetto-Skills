-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gl_standalone_swap_jank.skill.yaml
-- Source SHA-256: 099d717e80e4a568d18a565c1bec7714b24451ed809a8c35527cdff3c29eabc9
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
swap_events AS (
  SELECT
    s.ts,
    s.dur,
    s.name AS slice_name,
    t.utid,
    t.name AS thread_name,
    p.name AS process_name,
    LAG(s.ts) OVER (PARTITION BY t.utid ORDER BY s.ts) AS prev_swap_ts
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND (i.target_process != '' OR COALESCE(t.name, '') NOT GLOB 'RenderThread*')
    AND (
      s.name GLOB '*eglSwapBuffers*' OR s.name GLOB '*SwapBuffers*' OR
      s.name GLOB '*vkQueuePresent*' OR
      s.name GLOB '*ANativeWindow_queueBuffer*'
    )
),
swap_intervals AS (
  SELECT
    *,
    ts - prev_swap_ts AS interval_ns
  FROM swap_events
  WHERE prev_swap_ts IS NOT NULL
    AND ts > prev_swap_ts
    AND ts - prev_swap_ts BETWEEN 4000000 AND 100000000
),
target AS (
  SELECT COALESCE(
    (SELECT CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER) FROM swap_intervals),
    16666667
  ) AS target_interval_ns
)
SELECT
  printf('%d', ts) AS ts,
  ROUND(interval_ns / 1e6, 2) AS interval_ms,
  ROUND(dur / 1e6, 2) AS swap_dur_ms,
  slice_name,
  thread_name,
  process_name
FROM swap_intervals
WHERE interval_ns > (SELECT target_interval_ns * 1.5 FROM target)
ORDER BY interval_ns DESC
LIMIT 100

-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gl_standalone_swap_jank.skill.yaml
-- Source SHA-256: 099d717e80e4a568d18a565c1bec7714b24451ed809a8c35527cdff3c29eabc9
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

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
  process_name,
  thread_name,
  COUNT(*) AS swap_count,
  ROUND((SELECT target_interval_ns FROM target) / 1e6, 2) AS target_interval_ms,
  ROUND(AVG(interval_ns) / 1e6, 2) AS avg_interval_ms,
  ROUND(PERCENTILE(interval_ns, 0.95) / 1e6, 2) AS p95_interval_ms,
  ROUND(MAX(interval_ns) / 1e6, 2) AS max_interval_ms,
  SUM(CASE WHEN interval_ns > (SELECT target_interval_ns * 1.5 FROM target) THEN 1 ELSE 0 END) AS missed_like_count,
  CASE
    WHEN MAX(interval_ns) > (SELECT target_interval_ns * 4 FROM target) THEN 'critical'
    WHEN PERCENTILE(interval_ns, 0.95) > (SELECT target_interval_ns * 2 FROM target) THEN 'warning'
    WHEN SUM(CASE WHEN interval_ns > (SELECT target_interval_ns * 1.5 FROM target) THEN 1 ELSE 0 END) > 0 THEN 'notice'
    ELSE 'normal'
  END AS rating
FROM swap_intervals
GROUP BY process_name, thread_name
ORDER BY missed_like_count DESC, max_interval_ms DESC
LIMIT 50

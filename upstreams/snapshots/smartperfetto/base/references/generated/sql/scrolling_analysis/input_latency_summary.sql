-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
timing_config AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 0.5)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
scoped_events AS (
  SELECT *
  FROM android_input_events
  WHERE (process_name GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
),
ranked_processes AS (
  SELECT
    process_name,
    COUNT(*) as event_count,
    ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, MAX(total_latency_dur) DESC) as rn
  FROM scoped_events
  GROUP BY process_name
),
target AS (
  SELECT process_name
  FROM ranked_processes
  WHERE rn = 1
),
target_events AS (
  SELECT e.*
  FROM scoped_events e
  JOIN target t ON e.process_name = t.process_name
),
frame_backlog AS (
  SELECT frame_id, COUNT(*) as event_count
  FROM target_events
  WHERE frame_id IS NOT NULL
  GROUP BY frame_id
)
SELECT
  (SELECT process_name FROM target) as target_process,
  COUNT(*) as total_input_events,
  SUM(CASE WHEN event_action = 'MOVE' THEN 1 ELSE 0 END) as move_events,
  ROUND(AVG(dispatch_latency_dur) / 1e6, 2) as avg_dispatch_ms,
  ROUND(MAX(dispatch_latency_dur) / 1e6, 2) as max_dispatch_ms,
  ROUND(AVG(handling_latency_dur) / 1e6, 2) as avg_handling_ms,
  ROUND(PERCENTILE(handling_latency_dur, 0.95) / 1e6, 2) as p95_handling_ms,
  ROUND(MAX(handling_latency_dur) / 1e6, 2) as max_handling_ms,
  ROUND(AVG(ack_latency_dur) / 1e6, 2) as avg_ack_ms,
  ROUND(MAX(ack_latency_dur) / 1e6, 2) as max_ack_ms,
  ROUND(AVG(end_to_end_latency_dur) / 1e6, 2) as avg_e2e_ms,
  ROUND(MAX(end_to_end_latency_dur) / 1e6, 2) as max_e2e_ms,
  SUM(CASE
    WHEN handling_latency_dur > (SELECT vsync_period_ns FROM timing_config) * ${input_handling_budget_ratio|0.5}
    THEN 1 ELSE 0 END) as slow_handling_events,
  (SELECT COUNT(*) FROM frame_backlog WHERE event_count >= ${input_event_backlog_threshold|3}) as input_backlog_frames,
  SUM(CASE WHEN is_speculative_frame = 1 THEN 1 ELSE 0 END) as speculative_frame_matches,
  ROUND((SELECT vsync_period_ns FROM timing_config) / 1e6, 2) as frame_budget_ms,
  CASE
    WHEN COUNT(*) = 0 THEN '无 input 事件'
    WHEN SUM(CASE WHEN handling_latency_dur > (SELECT vsync_period_ns FROM timing_config) * ${input_handling_budget_ratio|0.5} THEN 1 ELSE 0 END) = 0 THEN '正常'
    WHEN MAX(handling_latency_dur) > (SELECT vsync_period_ns FROM timing_config) * 2 THEN '严重'
    ELSE '需关注'
  END as input_latency_rating
FROM target_events

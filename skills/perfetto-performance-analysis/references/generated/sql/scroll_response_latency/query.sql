-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/scroll_response_latency.skill.yaml
-- Source SHA-256: d89dec74765b5e8b1f68f450ec1579c149e0d6b3db6adb5e0ffe9c04b2799859
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH move_events AS (
  SELECT
    dispatch_ts as input_ts,
    process_name,
    upid,
    ROW_NUMBER() OVER (PARTITION BY upid ORDER BY dispatch_ts) as move_idx
  FROM android_input_events
  WHERE (process_name GLOB '${package}*' OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
),
gesture_starts AS (
  SELECT
    m1.input_ts as gesture_ts,
    m1.process_name,
    m1.upid
  FROM move_events m1
  LEFT JOIN move_events m2 ON m1.upid = m2.upid AND m2.move_idx = m1.move_idx - 1
  WHERE m2.input_ts IS NULL OR (m1.input_ts - m2.input_ts) > 500000000
),
first_frames AS (
  SELECT
    g.gesture_ts,
    g.process_name,
    MIN(f.ts) as frame_ts,
    (SELECT f2.dur FROM actual_frame_timeline_slice f2
     WHERE f2.upid = g.upid AND f2.ts >= g.gesture_ts
     ORDER BY f2.ts LIMIT 1) as frame_dur
  FROM gesture_starts g
  LEFT JOIN actual_frame_timeline_slice f ON f.upid = g.upid AND f.ts >= g.gesture_ts
  GROUP BY g.gesture_ts, g.process_name
)
SELECT
  printf('%d', gesture_ts) as gesture_ts,
  process_name,
  printf('%d', frame_ts) as first_frame_ts,
  ROUND((frame_ts - gesture_ts) / 1e6, 2) as response_latency_ms,
  ROUND(frame_dur / 1e6, 2) as first_frame_dur_ms,
  CASE
    WHEN (frame_ts - gesture_ts) / 1e6 < 50 THEN '优秀'
    WHEN (frame_ts - gesture_ts) / 1e6 < 100 THEN '良好'
    WHEN (frame_ts - gesture_ts) / 1e6 < 200 THEN '需优化'
    ELSE '严重'
  END as rating
FROM first_frames
WHERE frame_ts IS NOT NULL
ORDER BY response_latency_ms DESC

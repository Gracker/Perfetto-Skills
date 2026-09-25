-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/scroll_response_latency.skill.yaml
-- Source SHA-256: 830043fea116a8e503cbd283fed3b735fb091115466495f32c784c1fab435142
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- The single read path for stdlib android_input_events. Skill contract:
-- event_action is the uppercase action without the Android prefix (MOVE, DOWN,
-- UP, CANCEL, ...). Newer trace processors report legacy atrace actions as
-- ACTION_MOVE/ACTION_DOWN/ACTION_UP; older ones reported MOVE/DOWN/UP. Every
-- other column passes through unchanged, NULL actions stay NULL. The column
-- list is the set every supported runtime has (v58.2 lacks frame_event_time);
-- keep it aligned with scrolling_analysis's input_data_fallback_view. NOT MATERIALIZED: consumers read it more than once
-- under their own filters, so SQLite should inline it rather than copy the table.
android_input_events_normalized AS NOT MATERIALIZED (
  SELECT
    dispatch_latency_dur, handling_latency_dur, ack_latency_dur,
    total_latency_dur, end_to_end_latency_dur,
    tid, thread_name, upid, pid, process_name,
    event_type,
    CASE WHEN event_action GLOB 'ACTION_*' THEN SUBSTR(event_action, 8)
      ELSE event_action END AS event_action,
    event_seq, event_channel, normalized_event_channel, input_event_id,
    read_time, dispatch_track_id, dispatch_ts, dispatch_dur,
    receive_ts, receive_dur, receive_track_id,
    frame_id, is_speculative_frame, event_time
  FROM android_input_events
)
,
move_events AS (
  SELECT
    dispatch_ts as input_ts,
    process_name,
    upid,
    ROW_NUMBER() OVER (PARTITION BY upid ORDER BY dispatch_ts) as move_idx
  FROM android_input_events_normalized
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
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

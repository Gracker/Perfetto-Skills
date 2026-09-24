-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_events_in_range.skill.yaml
-- Source SHA-256: aa8801102419f8c6eca4acd64f77667749850504022424e3996ef4d0e2ae7caf
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

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
SELECT
  printf('%d', dispatch_ts) as event_ts,
  event_type,
  event_action,
  ROUND(dispatch_latency_dur / 1e6, 2) as dispatch_latency_ms,
  ROUND(handling_latency_dur / 1e6, 2) as handling_latency_ms,
  ROUND(ack_latency_dur / 1e6, 2) as ack_latency_ms,
  ROUND(total_latency_dur / 1e6, 2) as total_latency_ms,
  ROUND(end_to_end_latency_dur / 1e6, 2) as e2e_latency_ms,
  process_name,
  normalized_event_channel as normalized_channel,
  CASE
    WHEN total_latency_dur / 1e6 > 200 THEN '严重延迟'
    WHEN total_latency_dur / 1e6 > 100 THEN '延迟偏高'
    WHEN total_latency_dur / 1e6 > 50 THEN '轻微延迟'
    ELSE '正常'
  END as dispatch_status
FROM android_input_events_normalized
WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
  AND ('${event_type}' = '' OR event_type = '${event_type}')
  AND ('${event_action}' = '' OR '${event_action}' IN (event_action, 'ACTION_' || event_action))
ORDER BY dispatch_ts ASC

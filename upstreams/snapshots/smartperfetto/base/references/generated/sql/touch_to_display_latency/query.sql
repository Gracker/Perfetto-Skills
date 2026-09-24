-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/touch_to_display_latency.skill.yaml
-- Source SHA-256: 1fc1f7b408fd541ca0186fd2bbf779282392819e110e55e2026a0cd645a9700f
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

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
  printf('%d', dispatch_ts) as input_ts,
  process_name,
  event_type,
  event_action,
  ROUND(dispatch_latency_dur / 1e6, 2) as dispatch_latency_ms,
  ROUND(handling_latency_dur / 1e6, 2) as handling_latency_ms,
  ROUND(ack_latency_dur / 1e6, 2) as ack_latency_ms,
  ROUND(total_latency_dur / 1e6, 2) as total_latency_ms,
  ROUND(end_to_end_latency_dur / 1e6, 2) as e2e_latency_ms,
  normalized_event_channel as normalized_channel,
  is_speculative_frame,
  CASE
    WHEN total_latency_dur / 1e6 < 32 THEN '优秀'
    WHEN total_latency_dur / 1e6 < 64 THEN '良好'
    WHEN total_latency_dur / 1e6 < 100 THEN '可接受'
    WHEN total_latency_dur / 1e6 < 150 THEN '需优化'
    ELSE '严重'
  END as rating
FROM android_input_events_normalized
WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
  AND ('${event_type}' = '' OR event_type = '${event_type}')
ORDER BY total_latency_dur DESC

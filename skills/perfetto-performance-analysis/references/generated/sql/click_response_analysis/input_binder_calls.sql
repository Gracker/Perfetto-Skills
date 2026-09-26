-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: b4e342987eae11ebb02d0693221a0e10ba48572187f89156a889763249cd5cf8
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
-- Frame association: the stdlib matches an event to the Choreographer#doFrame
-- its delivery overlaps (exact) or else to the next doFrame on the receiving
-- thread with no time bound (is_speculative_frame = 1), and derives
-- end_to_end_latency_dur from that frame. A speculative frame is a candidate,
-- not proof the event was consumed there, so frame linkage, presentation
-- latency and per-frame attribution read exact_frame_id /
-- exact_end_to_end_latency_dur. frame_association labels raw values for
-- display: none, exact, speculative, or unknown (a frame with no flag, which
-- is not treated as exact).
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
    frame_id, is_speculative_frame, event_time,
    CASE WHEN frame_id IS NOT NULL AND is_speculative_frame = 0
      THEN frame_id END AS exact_frame_id,
    CASE WHEN frame_id IS NOT NULL AND is_speculative_frame = 0
      THEN end_to_end_latency_dur END AS exact_end_to_end_latency_dur,
    CASE
      WHEN frame_id IS NULL THEN 'none'
      WHEN is_speculative_frame = 0 THEN 'exact'
      WHEN is_speculative_frame = 1 THEN 'speculative'
      ELSE 'unknown'
    END AS frame_association
  FROM android_input_events
)
,
slow_inputs AS (
  SELECT
    dispatch_ts as input_ts,
    receive_ts + receive_dur as input_end_ts,
    total_latency_dur
  FROM android_input_events_normalized
  WHERE process_name = '${target_process.data[0].process_name}'
    AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
    AND total_latency_dur > ${thread_state_min_dur_ms|50} * 1000000
  ORDER BY total_latency_dur DESC
  LIMIT 10
)
SELECT
  bt.server_process,
  bt.aidl_name,
  COUNT(*) as call_count,
  SUM(bt.client_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(bt.client_dur) / 1e6, 2) as avg_dur_ms,
  SUM(CASE WHEN bt.is_main_thread THEN 1 ELSE 0 END) as main_thread_calls
FROM android_binder_txns bt
JOIN slow_inputs si ON (
  bt.client_ts >= si.input_ts AND bt.client_ts < si.input_end_ts
)
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
GROUP BY bt.server_process, bt.aidl_name
ORDER BY total_dur_ms DESC
LIMIT 15

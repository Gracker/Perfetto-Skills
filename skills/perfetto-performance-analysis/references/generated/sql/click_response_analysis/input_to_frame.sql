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
SELECT
  ie.event_type,
  ie.event_action,
  ie.exact_end_to_end_latency_dur / 1e6 as e2e_latency_ms,
  ie.exact_frame_id as frame_id,
  -- 关联帧信息
  af.dur / 1e6 as frame_dur_ms,
  ie.total_latency_dur / 1e6 as input_latency_ms,
  -- 输入到关联帧的延迟
  CASE
    WHEN ie.exact_end_to_end_latency_dur / 1e6 > ${critical_event_threshold_ms|200} THEN 'critical'
    WHEN ie.exact_end_to_end_latency_dur / 1e6 > ${slow_event_threshold_ms|100} THEN 'warning'
    WHEN ie.exact_end_to_end_latency_dur / 1e6 > ${thread_state_min_dur_ms|50} THEN 'notice'
    ELSE 'good'
  END as rating
FROM android_input_events_normalized ie
-- exact association only (see fragments/android_input_events_normalized.sql)
LEFT JOIN android_frames af ON ie.exact_frame_id = af.frame_id
WHERE ie.process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR ie.receive_ts + ie.receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR ie.dispatch_ts < ${end_ts})
  AND ie.exact_frame_id IS NOT NULL
  AND ie.exact_end_to_end_latency_dur > 0
ORDER BY ie.exact_end_to_end_latency_dur DESC
LIMIT 20

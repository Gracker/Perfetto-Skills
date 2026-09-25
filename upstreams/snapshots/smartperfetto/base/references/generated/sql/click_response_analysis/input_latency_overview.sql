-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: b4e342987eae11ebb02d0693221a0e10ba48572187f89156a889763249cd5cf8
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
  COUNT(*) as total_events,
  -- 分发延迟（系统责任）
  ROUND(AVG(dispatch_latency_dur) / 1e6, 2) as avg_dispatch_ms,
  ROUND(MAX(dispatch_latency_dur) / 1e6, 2) as max_dispatch_ms,
  -- 处理延迟（应用责任）
  ROUND(AVG(handling_latency_dur) / 1e6, 2) as avg_handling_ms,
  ROUND(MAX(handling_latency_dur) / 1e6, 2) as max_handling_ms,
  -- ACK 延迟
  ROUND(AVG(ack_latency_dur) / 1e6, 2) as avg_ack_ms,
  -- dispatch-to-ACK 总延迟
  ROUND(AVG(total_latency_dur) / 1e6, 2) as avg_total_ms,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_total_ms,
  -- Input→Frame: exact association only (see fragments/android_input_events_normalized.sql); speculative counted separately, NULL = unmeasured.
  ROUND(AVG(exact_end_to_end_latency_dur) / 1e6, 2) as avg_e2e_ms,
  ROUND(MAX(exact_end_to_end_latency_dur) / 1e6, 2) as max_e2e_ms,
  SUM(CASE WHEN frame_association = 'speculative' THEN 1 ELSE 0 END) as speculative_frame_events,
  -- 评级
  CASE
    WHEN AVG(total_latency_dur) / 1e6 < 50 THEN '优秀 (<50ms)'
    WHEN AVG(total_latency_dur) / 1e6 < ${slow_event_threshold_ms|100} THEN '良好 (50-100ms)'
    WHEN AVG(total_latency_dur) / 1e6 < ${critical_event_threshold_ms|200} THEN '可接受 (100-200ms)'
    ELSE '较差 (>200ms)'
  END as rating
FROM android_input_events_normalized
WHERE process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})

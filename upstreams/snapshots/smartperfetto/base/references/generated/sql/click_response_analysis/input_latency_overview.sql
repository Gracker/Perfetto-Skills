-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: ce6eab4ca8f6e37319dd89eb7e9063d577143f539fc1106875fe97f15999cb18
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
  -- 输入到关联帧延迟（需要 frame_id/FrameTimeline）
  ROUND(AVG(end_to_end_latency_dur) / 1e6, 2) as avg_e2e_ms,
  ROUND(MAX(end_to_end_latency_dur) / 1e6, 2) as max_e2e_ms,
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

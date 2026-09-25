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
  event_type,
  event_action,
  event_channel,
  normalized_event_channel as normalized_channel,
  ROUND(total_latency_dur / 1e6, 2) as total_ms,
  ROUND(dispatch_latency_dur / 1e6, 2) as dispatch_ms,
  ROUND(handling_latency_dur / 1e6, 2) as handling_ms,
  ROUND(ack_latency_dur / 1e6, 2) as ack_ms,
  ROUND(end_to_end_latency_dur / 1e6, 2) as e2e_ms,
  thread_name,
  process_name,
  frame_id,
  -- 时间戳用于详细分析
  printf('%d', dispatch_ts) as event_ts,
  printf('%d', receive_ts + receive_dur) as event_end_ts,
  -- Perfetto 跳转参数（前后各扩展 20ms）
  printf('%d', CAST(dispatch_ts - 20000000 AS INTEGER)) as perfetto_start,
  printf('%d', CAST(receive_ts + receive_dur + 20000000 AS INTEGER)) as perfetto_end,
  CASE
    WHEN total_latency_dur / 1e6 > ${critical_event_threshold_ms|200} THEN 'critical'
    WHEN total_latency_dur / 1e6 > ${slow_event_threshold_ms|100} THEN 'warning'
    ELSE 'notice'
  END as severity,
  -- 延迟主要来源
  CASE
    WHEN dispatch_latency_dur > handling_latency_dur AND dispatch_latency_dur > ack_latency_dur THEN '系统分发'
    WHEN handling_latency_dur > ack_latency_dur THEN '应用处理'
    ELSE 'ACK'
  END as main_bottleneck
FROM android_input_events_normalized
WHERE process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
  AND total_latency_dur > ${slow_event_threshold_ms|100} * 1000000  -- > slow threshold
ORDER BY total_latency_dur DESC
LIMIT 20

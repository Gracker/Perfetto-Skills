-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 1985d22caae082895e3249e940e3e891a1296411bab5c6844647aee083f7a517
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

-- 父 Skill 直接传入 android_input_events 的精确事件边界；不猜测相邻事件。
-- Frame 阶段自 Perfetto 7b573c1 起由 _android_input_frames 扩展提供。
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
target_event AS (
  SELECT *
  FROM android_input_events_normalized
  WHERE process_name = '${process_name}'
    AND dispatch_ts = ${event_ts}
    AND receive_ts + receive_dur = ${event_end_ts}
  ORDER BY input_event_id, event_channel
  LIMIT 1
)
SELECT
  e.input_event_id as input_id,
  e.event_channel as channel,
  -- dispatch-to-ACK，与列标签一致；end-to-end 上屏延迟不在这张表里。
  ROUND(e.total_latency_dur / 1e6, 2) as total_latency_ms,
  CASE WHEN e.read_time IS NOT NULL THEN printf('%d', e.read_time) END as reader_ts,
  ROUND(s_read.dur / 1e6, 2) as reader_ms,
  CASE WHEN e.dispatch_ts IS NOT NULL THEN printf('%d', e.dispatch_ts) END as dispatch_ts,
  ROUND(s_dispatch.dur / 1e6, 2) as dispatch_ms,
  CASE WHEN e.receive_ts IS NOT NULL THEN printf('%d', e.receive_ts) END as receive_ts,
  ROUND(s_receive.dur / 1e6, 2) as receive_ms,
  CASE WHEN s_consume.ts IS NOT NULL THEN printf('%d', s_consume.ts) END as consume_ts,
  ROUND(s_consume.dur / 1e6, 2) as consume_ms,
  CASE WHEN frames.ts_do_frame IS NOT NULL THEN printf('%d', frames.ts_do_frame) END as frame_ts,
  ROUND(frames.dur_do_frame / 1e6, 2) as frame_ms,
  e.is_speculative_frame
FROM target_event e
LEFT JOIN slice s_read
  ON s_read.ts = e.read_time
  AND s_read.track_id != 0
  AND s_read.name GLOB 'UnwantedInteractionBlocker::notifyMotion*'
LEFT JOIN slice s_dispatch
  ON s_dispatch.ts = e.dispatch_ts
  AND s_dispatch.track_id = e.dispatch_track_id
LEFT JOIN slice s_receive
  ON s_receive.ts = e.receive_ts
  AND s_receive.track_id = e.receive_track_id
LEFT JOIN _input_consumers_lookup s_consume
  ON s_consume.cookie = e.event_seq
LEFT JOIN _android_input_frames frames
  ON frames.frame_id = e.frame_id
  AND frames.upid = e.upid
